"""Kagi account access: login, read live state, apply changes.

Kagi has no settings API, but its settings pages are server-rendered forms and
the Assistant is a JSON API. `read` scrapes the pages with a logged-in browser
and `apply` posts the same requests the pages would.

Login uses the Kagi session link from `KAGI_SESSION_LINK` (set in ~/.secrets).
The link is a bearer credential: it is never printed, and any Playwright error
that could echo the navigated URL is redacted before it propagates.
"""

from __future__ import annotations

import os
from typing import TYPE_CHECKING, Any, Self, cast

from playwright.sync_api import APIResponse, Browser, Page, Playwright, sync_playwright

from kagi_config.config import Assistant, Lens
from kagi_config.paths import state_dir
from kagi_config.plan import Change, LiveState, Op, Resource

if TYPE_CHECKING:
    from pathlib import Path

SESSION_ENV = "KAGI_SESSION_LINK"
# The `token` in the name means the root gitignore (`**/*token*`) catches this
# file if it is ever copied into the repo.
STORAGE_FILE = "kagi-session-token.json"
REDACTED = "<KAGI_SESSION_LINK>"
BASE = "https://kagi.com"
ASSISTANT_API = "https://assistant.kagi.com/api"
HTTP_ERROR = 400
# /lenses/update takes about 10 s on Kagi's side and the gateway cuts it off at
# 10 s, so the response is sometimes 504 although the write has landed. 504 is
# tolerated on every write; the re-read after apply decides what took effect.
GATEWAY_TIMEOUT = 504

RANK_KIND = {"block": "-2", "lower": "-1", "raise": "1", "pin": "2"}
KIND_RANK = {kind: action for action, kind in RANK_KIND.items()}
NO_REGION = "no_region"

# Browser-side extraction. The settings pages are plain HTML; these run in the
# page so no HTML parser is needed on the Python side.
# The empty table holds a placeholder row, so select by the domain cell.
JS_RANKED = """() => [...document.querySelectorAll('._0_rules_table_list ._0_rule_domain_name')]
    .map(td => [td.innerText.trim(),
                td.closest('tr').querySelector('input[name=kind]:checked').value])"""
JS_LENSES = """() => [...document.querySelectorAll('._0_lens_item[data-id]')].map(e => ({
    id: e.dataset.id,
    name: e.querySelector('.lens_title > div').innerText.trim(),
    active: !!e.closest('#_0_lens_table_active'),
    custom: e.querySelector('.lens_title').tagName === 'A'}))"""
JS_LENS_FORM = """() => Object.fromEntries(
    [...document.querySelectorAll('form[action="/lenses/update"] input[name]')]
    .filter(e => e.type !== 'radio' || e.checked)
    .map(e => [e.name, e.value]))"""


class SessionError(RuntimeError):
    """Login failed or the session link is missing. Message is safe to print."""


class ApplyError(RuntimeError):
    """Kagi rejected a write. Message names the endpoint and status only."""


def session_link() -> str:
    link = os.environ.get(SESSION_ENV, "").strip()
    if not link:
        msg = f"{SESSION_ENV} is not set; add it to ~/.secrets from Kagi Settings > Account"
        raise SessionError(msg)
    return link


class Session:
    """A logged-in Kagi browser context. Use as a context manager."""

    def __init__(self, *, headless: bool = True) -> None:
        self.headless = headless
        self._pw: Playwright | None = None
        self._browser: Browser | None = None
        self._page: Page | None = None

    def __enter__(self) -> Self:
        self._pw = sync_playwright().start()
        self._browser = self._pw.chromium.launch(headless=self.headless)
        storage = state_dir() / STORAGE_FILE
        context = self._browser.new_context(
            storage_state=str(storage) if storage.exists() else None,
        )
        self._page = context.new_page()
        self._login(storage)
        return self

    def __exit__(self, *exc: object) -> None:
        if self._browser is not None:
            self._browser.close()
        if self._pw is not None:
            self._pw.stop()

    @property
    def page(self) -> Page:
        if self._page is None:
            msg = "Session must be entered before use"
            raise SessionError(msg)
        return self._page

    def _login(self, storage: Path) -> None:
        link = session_link()
        try:
            self.page.goto(link, wait_until="domcontentloaded")
            self.page.goto(f"{BASE}/settings", wait_until="domcontentloaded")
        except Exception as exc:  # noqa: BLE001 - any Playwright error may echo the link
            msg = f"login navigation failed: {str(exc).replace(link, REDACTED)}"
            raise SessionError(msg) from None
        if "/settings" not in self.page.url:
            landed = self.page.url.replace(link, REDACTED)
            msg = f"session link did not produce a logged-in session (landed on {landed})"
            raise SessionError(msg)
        self.page.context.storage_state(path=str(storage))
        storage.chmod(0o600)

    # -- read ---------------------------------------------------------------

    def read(self) -> LiveState:
        live = LiveState()
        self.page.goto(f"{BASE}/settings/user_ranked", wait_until="networkidle")
        live.ranked = {domain: KIND_RANK[kind] for domain, kind in self.page.evaluate(JS_RANKED)}
        lenses = self._lens_list()
        live.lens_ids = {lens["name"]: lens["id"] for lens in lenses}
        live.builtin_available = {lens["name"] for lens in lenses if not lens["custom"]}
        live.builtin_lenses = {
            lens["name"] for lens in lenses if not lens["custom"] and lens["active"]
        }
        for lens in lenses:
            if lens["custom"]:
                self.page.goto(
                    f"{BASE}/settings/update_lens?id={lens['id']}", wait_until="networkidle"
                )
                form = self.page.evaluate(JS_LENS_FORM)
                live.lenses[lens["name"]] = parse_lens(form, enabled=lens["active"])
        names_by_id = {lens_id: name for name, lens_id in live.lens_ids.items()}
        init = self._api("GET", "/init").json()
        for raw in init["custom_assistants"]:
            live.assistant_ids[raw["name"]] = raw["uuid"]
            live.assistants[raw["name"]] = parse_assistant(raw, names_by_id)
        return live

    def _lens_list(self) -> list[dict[str, Any]]:
        self.page.goto(f"{BASE}/settings/lenses", wait_until="networkidle")
        return self.page.evaluate(JS_LENSES)

    # -- apply --------------------------------------------------------------

    def apply(self, changes: list[Change], live: LiveState) -> None:
        """Post every change, ordered so ids exist before they are referenced."""
        self._apply_ranked(changes)
        for change in _of(changes, Resource.ASSISTANT, Op.DELETE):
            self._api("DELETE", f"/assistants/{live.assistant_ids[change.key]}")
        for change in _of(changes, Resource.LENS, Op.DELETE):
            self._post("/lenses/delete", {"id": live.lens_ids[change.key]})
        ids = self._apply_lenses(changes, live)
        for change in _of(changes, Resource.ASSISTANT, Op.CREATE):
            self._api("POST", "/assistants", assistant_json(_assistant(change.after), ids))
        for change in _of(changes, Resource.ASSISTANT, Op.UPDATE):
            uuid = live.assistant_ids[change.key]
            self._api("PATCH", f"/assistants/{uuid}", assistant_json(_assistant(change.after), ids))

    def _apply_ranked(self, changes: list[Change]) -> None:
        by_action: dict[str, list[str]] = {}
        for change in _of(changes, Resource.RANKED, Op.CREATE, Op.UPDATE):
            by_action.setdefault(str(change.after), []).append(change.key)
        for action, domains in by_action.items():
            # Re-adding an existing domain with a new kind updates it in place.
            self._post(
                "/esr/user_rules/bulk",
                {
                    "domain_list": "\n".join(domains),
                    "k": RANK_KIND[action],
                    "redirect": "/settings/user_ranked",
                },
            )
        for change in _of(changes, Resource.RANKED, Op.DELETE):
            self._post("/esr/user_rules/delete", {"domain": change.key})

    def _apply_lenses(self, changes: list[Change], live: LiveState) -> dict[str, str]:
        """Create and update lenses, set active states, and return name -> id."""
        for change in _of(changes, Resource.LENS, Op.CREATE):
            self._post("/lenses/create", lens_form(_lens(change.after)))
        for change in _of(changes, Resource.LENS, Op.UPDATE):
            form = lens_form(_lens(change.after)) | {"id": live.lens_ids[change.key]}
            self._post("/lenses/update", form)
        lenses = self._lens_list()
        ids = {lens["name"]: lens["id"] for lens in lenses}
        active = {lens["name"] for lens in lenses if lens["active"]}
        for change in _of(changes, Resource.BUILTIN_LENS, Op.CREATE, Op.DELETE):
            self._set_active(ids, active, change.key, enabled=change.op is Op.CREATE)
        for change in _of(changes, Resource.LENS, Op.CREATE, Op.UPDATE):
            self._set_active(ids, active, change.key, enabled=_lens(change.after).enabled)
        return ids

    def _set_active(
        self, ids: dict[str, str], active: set[str], name: str, *, enabled: bool
    ) -> None:
        # /lenses/subscribe toggles, so only post when the state differs.
        # Enabling needs the slot to insert at; without `next_index` Kagi
        # answers 302 and changes nothing. Appending at the end is enough.
        if (name in active) == enabled:
            return
        form = {"lens_id": ids[name]}
        if enabled:
            form["next_index"] = str(len(active))
        self._post("/lenses/subscribe", form)
        active.symmetric_difference_update({name})

    def _post(self, path: str, form: dict[str, str]) -> None:
        fields = cast("dict[str, str | float | bool]", form)
        response = self.page.request.post(BASE + path, form=fields, max_redirects=0)
        _check(response, f"POST {path}")

    def _api(self, method: str, path: str, data: dict[str, Any] | None = None) -> APIResponse:
        response = self.page.request.fetch(
            ASSISTANT_API + path,
            method=method,
            data=data,
            headers={"Content-Type": "application/json"} if data is not None else None,
        )
        _check(response, f"{method} {path}")
        return response


def _of(changes: list[Change], resource: Resource, *ops: Op) -> list[Change]:
    return [c for c in changes if c.resource is resource and c.op in ops]


def _check(response: APIResponse, what: str) -> None:
    if response.status >= HTTP_ERROR and response.status != GATEWAY_TIMEOUT:
        msg = f"{what} failed with HTTP {response.status}: {response.text()[:200]}"
        raise ApplyError(msg)


def _lens(value: object) -> Lens:
    if not isinstance(value, Lens):
        msg = f"expected a Lens change, got {type(value).__name__}"
        raise TypeError(msg)
    return value


def _assistant(value: object) -> Assistant:
    if not isinstance(value, Assistant):
        msg = f"expected an Assistant change, got {type(value).__name__}"
        raise TypeError(msg)
    return value


# -- form and JSON mapping (pure, unit-tested) --------------------------------


def lens_form(lens: Lens) -> dict[str, str]:
    """Every field of `/lenses/create` and `/lenses/update`.

    Fields the config does not model (description, date range, template, file
    type, bang shortcut) are posted at their defaults, so an `apply` resets
    them. The config is the full truth for a managed lens.
    """
    return {
        "name": lens.name,
        "included_sites": ", ".join(lens.include_domains),
        "included_keywords": ", ".join(lens.include_keywords),
        "description": "",
        "search_region": lens.region or NO_REGION,
        "date_range": "0",
        "before_time": "",
        "after_time": "",
        "excluded_sites": ", ".join(lens.exclude_domains),
        "excluded_keywords": ", ".join(lens.exclude_keywords),
        "shortcut_keyword": "",
        "autocomplete_keywords": "false",
        "template": "0",
        "file_type": "",
        "share_copy_code": "false",
    }


def parse_lens(form: dict[str, str], *, enabled: bool) -> Lens:
    region = form.get("search_region", NO_REGION)
    return Lens(
        name=form["name"],
        include_domains=_split(form.get("included_sites", "")),
        exclude_domains=_split(form.get("excluded_sites", "")),
        include_keywords=_split(form.get("included_keywords", "")),
        exclude_keywords=_split(form.get("excluded_keywords", "")),
        region=None if region == NO_REGION else region,
        enabled=enabled,
    )


def assistant_json(assistant: Assistant, lens_ids: dict[str, str]) -> dict[str, Any]:
    return {
        "name": assistant.name,
        "llm_id": assistant.model,
        "instructions": assistant.instructions,
        "internet_access": assistant.internet,
        "personalizations": assistant.personalized,
        "lens_id": lens_ids[assistant.lens] if assistant.lens else None,
        "bang_trigger": assistant.bang,
    }


def parse_assistant(raw: dict[str, Any], lens_names: dict[str, str]) -> Assistant:
    lens_id = raw.get("lens_id")
    return Assistant(
        name=raw["name"],
        instructions=raw["instructions"],
        model=raw["llm_id"],
        bang=raw["bang_trigger"],
        lens=lens_names.get(lens_id) if lens_id else None,
        internet=raw["internet_access"],
        personalized=raw["personalizations"],
    )


def _split(value: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in value.split(",") if item.strip())


def read(*, headless: bool = True) -> LiveState:
    with Session(headless=headless) as session:
        return session.read()


def apply(changes: list[Change], live: LiveState, *, headless: bool = True) -> LiveState:
    """Apply `changes` and return the account state read back afterwards."""
    with Session(headless=headless) as session:
        session.apply(changes, live)
        return session.read()
