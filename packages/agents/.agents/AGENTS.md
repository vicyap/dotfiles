# Personal Agent Instructions

These instructions apply to all AI coding agents working for Victor Yap.

## Runtime Sources

`~/.agents`, `~/.claude`, and `~/.codex` are deployed from
`~/.dotfiles/packages/{agents,claude,codex}/`. Edit the tracked source, never
the deployed copy; `~/.dotfiles/AGENTS.md` owns the layout.

## Project Instructions

The nearest `AGENTS.md` is the source of truth for shared project guidance.
Claude-specific files start with `@AGENTS.md` and add only Claude-specific
behavior. Read a subdirectory's own `AGENTS.md` before working in that subtree.

## Operating Rules

1. Ask, don't assume. When intent, architecture, requirements, or a tool,
   config, or secrets-location choice is unclear, run a clarifying-questions
   interview before non-trivial work; invoke the `ask-clarifying-questions`
   skill when available. Never silently substitute a similar alternative for
   something the user specified.
2. Use the simplest solution that could work. No unrequested abstractions,
   flexibility, compatibility paths, config, secrets, dependencies, or
   speculative schema. In reviews and designs, surface clarification needs
   instead of adding scope.
3. Flag uncertainty explicitly and verify it. Never invent technical details:
   research them or say you do not know. Before a high-stakes or irreversible
   action (production database write or migration, payment, order
   transmission, PR merge), uncertainty is a hard stop; ask.
4. Exploration, investigation, review, and audit requests are read-only; report
   findings and recommendations.
5. Once the task is aligned and Victor has said to proceed, work the full
   bounded scope without item-by-item permission checks. Pause only for
   high-stakes uncertainty or a scope-changing decision.

Never: estimate implementation timelines; delete production databases or data
files without explicit approval; document, validate, or reference features that
are not implemented; add AI co-authorship attribution, badges, or watermarks.
Avoid overusing emojis.

## Writing And Artifacts

- Plans, READMEs, saved files, messages, and PR bodies are the current
  authoritative version only: no process narration, edit-order history,
  conversational preamble, or claims about how the content was produced.
  Design history, rejected alternatives, and dated decisions are fine.
- Ad-hoc data lookups: bullet points with only the requested fields; a table
  only when requested or clearly easier to scan.

## Done When

- Relevant tests pass, or the final response says which were not run and why.
- Lint, type-check, and formatters pass for touched files when configured.
- New behavior has an automated test or an explicit manual-verification note.
- The final summary names changed files, commands run, and remaining risks.

## Code Quality

- North star: Reduce the amount of information a developer must know, and make
  the remaining information obvious. Software complexity is whatever makes a
  system difficult to understand or modify—especially when essential
  information is hidden or distant.
- Prefer deep modules: substantial functionality behind a simple interface. A
  good abstraction replaces a large implementation burden with a much smaller
  interface burden.
- Hard limits on lines of code, cyclomatic complexity, or parameters per
  function are subjective and context dependent, not rules.
- Do not abstract until there are three real use cases.
- Prefer functional composition over inheritance.
- Match surrounding style; consistency within the file wins.
- Do not throw away or rewrite existing implementations without explicit
  permission. Preserve user changes and unrelated dirty work.
- When replacing an implementation, remove the old one entirely unless
  compatibility was requested, and add no deprecation comments.
- A paragraph-long comment justifying a workaround means the code is wrong;
  fix the code.
- Do not write tests that only assert mocked behavior. No mocks in end-to-end
  tests.
- Reproduce dictated wording, identifier names, constants, and user-specified
  text verbatim.
- When replicating a pattern or text edit, fuzzy-search for comparable
  instances and update every case that belongs to the same pattern, not only
  the named one.
- Cleanup passes (`/simplify`, review fixes) must not touch copy,
  documentation, or agent instructions as a side effect unless that is the
  target.
- Run `git status` before staging; never `git add -A` or `git add .` without
  having checked it first.

## PRs And Commits

Write PR titles and descriptions like git commit messages; under squash merges
the title is the commit subject and the body reads like the commit body. No
test plans, CI status, tool versions, markdown headers, or "Verification",
"Testing", "Numbers", or "Stats" sections. Plain factual language; avoid
inflated words such as critical, crucial, essential, significant,
comprehensive, robust, and elegant.

`gh pr edit` fails on repos with legacy Projects-classic fields ("Projects
(classic) is being deprecated", an open upstream `gh` bug); edit with
`gh api repos/{owner}/{repo}/pulls/{number} -f title="..." -f body="..."`.

## Rule Routing

Shared rules live in `~/.agents/rules/` (symlinked into `~/.claude/rules/`).
Claude Code injects a rule from its `paths:` frontmatter only when a matching
file is read, not written or created; Codex has no path mechanism. Read the
domain's rule before implementing:

- Python (`*.py`, `*.pyi`, `pyproject.toml`, `uv.lock`): `python.md`
- Elixir/Phoenix (`*.ex`, `*.exs`): `elixir.md`; add `ecto.md`, `phoenix.md`,
  `heex.md`, or `liveview.md` for schemas, repos, migrations, web modules,
  HEEx, LiveViews, or LiveView tests
- Frontend (JS, TS, CSS, HTML, Vue, Svelte): `frontend.md`; add
  `react-nextjs.md` for React, Next.js, `app/`, `pages/`, or `next.config.*`
- Go (`*.go`, `go.mod`): `go.md`
- Shell scripts and shell config: `shell.md`
- Terraform/OpenTofu: `terraform.md`
- Ignore files (`.gitignore`, `.dockerignore`, ...): `secrets.md`

## Skill Routing

User-level skills live in `~/.agents/skills/`. Use a skill when the user names
it or the task clearly matches its trigger. Read its `SKILL.md` completely and
follow its routing to referenced files before acting. Dotfiles-owned:
`ask-clarifying-questions`, `ddd`, `design-interfaces`, `event-sourcing`,
`simplify`, `writer-editor`.

## Tools

- Use Context7 proactively for current library, framework, SDK, API, CLI, or
  cloud service documentation; do not rely on memory for dependency APIs.
- Prefer the managed CLIs (`rg`, `fd`, `bat`, `eza`, `dust`, `procs`, `sd`) for
  local investigation. On Ubuntu, `fd` may be `fdfind` in non-interactive
  shells. Do not call interactive helpers such as `ff` from tool calls.
- Before proposing a CLI install or alias, check what the dotfiles already
  manage (`oma`, or `~/.dotfiles/AGENTS.md`).
- `ask` gives an external AI second opinion; `web` fetches a page as markdown.
  Run `--help` before relying on less obvious options.
- Shell history is atuin's. Never edit `~/.zsh_history`; use `atuin search`
  and `atuin history`.

## Machine-Specific Notes

Per-machine notes live in `~/.agents/AGENTS.local.md` (untracked).

@~/.agents/AGENTS.local.md
