# Kagi Configuration as Code

Declare Kagi search personalization (ranked domains, lenses, built-in lens
enablement, custom assistants) in `kagi.toml`, and apply it to kagi.com with a
Terraform-style `read`, `plan`, `apply` loop driven by Playwright. An ad hoc
`mine` step turns observed usage from Brave history and Kagi Assistant exports
into a proposed config diff. Run commands, the state-dir rule, and the secrets
rule are in `AGENTS.md`.

## Constraints that shape the design

- Kagi has no settings API. The public APIs (search, FastGPT, summarizer,
  enrichment) are read-only against the index. The settings pages are plain
  server-rendered forms and the Assistant is a JSON API, so `read` scrapes
  the pages with a logged-in browser and `apply` posts the same requests the
  pages would.
- A custom lens holds at most 10 included domains, 10 excluded domains, 5
  included keywords, and 5 excluded keywords, plus region, filetype, and date.
- Personalized results (`/settings/user_ranked`) block, lower, raise, or pin a
  domain everywhere, including inside Assistant; the page shows a 1000 cap.
- Custom assistants bind a model (required), an optional lens, personalized
  results, and a bang. The Assistant app no longer reads `q` or `lens` from
  its URL; a bang typed in the search box is the only programmatic way in,
  and it starts a thread and runs the query immediately.
- Kagi stores no server-side search history. Usage signal has to come from
  the local browser (Brave) and from manual Assistant thread exports.

## Design

**Discovery over allowlists.** Both custom lenses are exclude-only so the open
web stays visible; a lens only strips junk and gives Assistant something to
bind to. Known-good sites are raised globally in `[ranked]` rather than fenced
into a lens. Because the lens exclude cap is 10 domains while `[ranked] block`
allows 1000, domain blocking belongs in `[ranked]`; the lens's real payload is
its 5 exclude keywords and the assistant binding.

**Config is the full truth.** `apply` creates, updates, and deletes so the
account matches `kagi.toml`, deletions included. There is no state file; every
`plan` refreshes from the live account, like `terraform refresh`. `apply`
re-reads the account afterwards and exits non-zero if anything still differs,
because Kagi's lens endpoints sometimes answer 504 after the write has landed.
A lens update posts every form field, so the fields the config does not model
(description, date range, template, file type, bang shortcut) reset to their
defaults on each apply.

**Layout.**

| Path | Owns |
| --- | --- |
| `kagi.toml` | The declared state. The only file a normal edit touches. |
| `src/kagi_config/config.py` | Schema, loading, validation. Caps and cross-references fail at load time, never mid-apply. |
| `src/kagi_config/plan.py` | Pure diff of live state vs config. No browser. Rejects a built-in lens name Kagi does not offer. |
| `src/kagi_config/kagi.py` | Playwright session: login via session link, `read` live state, `apply` changes. The only module that knows the endpoints. |
| `src/kagi_config/mine.py` | Brave history and Assistant export mining. Writes a proposal to the state dir, never to `kagi.toml`. |
| `src/kagi_config/cli.py` | `read`, `plan`, `apply`, `mine`. |

**Seed content.** Global blocks for dev.to, medium.com, and a few SEO
listicle farms. Global raises for simonwillison.net, martinfowler.com,
nytimes.com (Wirecutter), camelcamelcamel, and forum sources. Two
exclude-only lenses, `Product Search` and `Engineering Blogs`. The nine
built-in lenses Kagi ships active stay active. Two custom assistants bound to
the custom lenses on `ki_research`, with bangs `!compare` and `!engblogs`.

## Verified against the live account (2026-09-07)

Personalized results, `/settings/user_ranked`:

- Rows are `._0_rules_table_list tr`; the domain is `._0_rule_domain_name`
  and the action is the checked `input[name=kind]` (`-2` block, `-1` lower,
  `1` raise, `2` pin). The empty table holds a placeholder row.
- `POST /esr/user_rules/bulk` with `domain_list` (newline separated), `k`, and
  `redirect` adds domains; re-adding a domain with a new `k` updates it.
  `POST /esr/user_rules` with `domain` and `kind` updates one row.
  `POST /esr/user_rules/delete` with `domain` removes one. The Video channels
  tab (`?t=video`) is a separate list and is not managed.

Lenses, `/settings/lenses`:

- Each lens is `._0_lens_item[data-id]`; the name is `.lens_title > div`;
  active lenses sit inside `#_0_lens_table_active`; a custom lens has an
  `a.lens_title`, a built-in a `div.lens_title`. Kagi offers 13 built-ins;
  nine are active on a fresh account.
- `POST /lenses/create` and `POST /lenses/update` (with `id`) take the form
  fields `name`, `included_sites`, `included_keywords`, `description`,
  `search_region` (`no_region` or a country code), `date_range`,
  `before_time`, `after_time`, `excluded_sites`, `excluded_keywords`,
  `shortcut_keyword`, `autocomplete_keywords`, `template`, `file_type`,
  `share_copy_code`. Lists are comma separated. A lens with no included
  domains is accepted. A built-in's edit page exposes only `name` (disabled)
  and `shortcut_keyword`.
- `GET /settings/update_lens?id=N` reads a custom lens back through the same
  form. `POST /lenses/delete` with `id` deletes. Update and delete take about
  10 s and the gateway cuts them at 10 s, so 504 responses are tolerated on
  every write and the post-apply re-read decides.
- Untested: deleting a lens while a surviving assistant still points at it
  (apply deletes the lens before patching the assistant). The post-apply
  re-read would report it.
- `POST /lenses/subscribe` with `lens_id` toggles. Disabling needs only
  `lens_id`; enabling also needs `next_index` (the slot to insert at) or Kagi
  answers 302 and changes nothing. A new custom lens starts active.
- In search URLs, built-ins use either a word (`forums`, `small_web`,
  `programming`, `academic`, `pdf`, `usenet_archive`) or a numeric id (News
  360 is `29`, Recipes `120`); custom lenses use their numeric id.

Assistant, `https://assistant.kagi.com/api`:

- `GET /api/init` returns `custom_assistants` (`uuid`, `name`, `llm_id`,
  `instructions`, `internet_access`, `personalizations`, `lens_id`,
  `bang_trigger`), `lenses` (`id`, `name` for every lens, built-in or
  custom), `models.models` (ids such as `ki_quick`, `ki_research`,
  `claude-5-sonnet`), and `settings.default_llm_id`.
- `POST /api/assistants` with that JSON creates (201); `llm_id` must be a
  non-empty model id, so there is no "account default" setting.
  `PATCH /api/assistants/{uuid}` updates; `DELETE` removes. `GET` on one
  assistant is not allowed.
- `kagi.com/search?q=!<bang> <query>` opens a new Assistant thread with the
  custom assistant and submits the query. `?q=`, `?lens=`, and `?profile=`
  on `/assistant` are ignored by the current app.

Brave: `visits.from_visit` attribution for results opened in a new tab is
still unverified; `mine` falls back to same-tab attribution until checked.

## Phases

1. **Scaffold.** Done.
2. **Verify against the live account.** Done; findings above.
3. **`read` and `apply`.** Done. Verified by applying a probe config from
   outside the repo (a raised and a blocked domain, an exclude-only lens
   created disabled, an assistant bound to it), then a second config that
   changed every field and enabled the lens, then a config with only the
   built-ins; `plan` was empty after each apply and the account ended clean.
4. **Setup.** Done: `mise run setup:kagi`, and a `kagi` alias in
   `nix/home/features/zsh.nix` that runs the CLI from any directory.
   Assistants are launched by typing their bang in the search box; a
   per-assistant alias or `open` command would only add a shell hop.
5. **Mining loop.** Run `kagi mine`, review the proposal in the state dir,
   copy what you want into `kagi.toml`, then `plan` and `apply`. The Brave
   `from_visit` check happens on the first real run.

## Privacy

The repository is public. Mined history, the copied Brave database, and the
browser session storage all live under `~/.local/state/kagi/`.
`tools/kagi/.gitignore` and the root `**/*token*` and `**/*secret*` patterns
are the second line of defence if something is written into the tree by
mistake. The session link is read from the environment and redacted from any
error output, since Playwright errors echo the navigated URL. `gitleaks` is
available from home-manager for a pre-commit check.

## Rejected alternatives

- **Allowlist lenses.** Ten domains cannot represent "product reviews" or
  "good engineering writing"; the point of search is finding sites you have
  not heard of. Exclude-only lenses plus global raises keep discovery.
- **Driving Chrome live through the extension.** Not repeatable and not
  reviewable. Config plus a script gives a diff to read before anything
  changes.
- **An `import` command.** `read` plus `plan` already shows anything
  unmanaged as a deletion. Revisit only if a hand-made lens needs to be
  adopted.
- **A scheduled loop.** Mining runs when invoked. A schedule can be added later
  with launchd once the proposal format has proven useful.
- **Auto-applying mined changes.** The proposal is a diff the user copies in;
  the config stays the single place changes are authored.
- **An HTML parser dependency.** The pages are read with DOM queries run in
  the browser that is already open for login, so Playwright is the only
  runtime dependency.
