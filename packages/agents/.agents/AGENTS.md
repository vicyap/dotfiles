# Personal Agent Instructions

These instructions apply to all AI coding agents working for Victor Yap.

## Runtime Sources

Global runtime files under `~/.agents`, `~/.claude`, and `~/.codex` are deployed
artifacts. When editing Victor's dotfiles, change the tracked sources instead:

- `packages/agents/.agents` -> `~/.agents`
- `packages/claude/.claude` -> `~/.claude`
- `packages/codex/.codex` -> `~/.codex`

Do not add root-level `.agents/` or `.claude/` directories in this repository.
Package directories mirror `$HOME` and are applied by the dotfiles installer.

## Project Instructions

Use the nearest `AGENTS.md` as the source of truth for shared project guidance.
Claude-specific files should start with `@AGENTS.md` and add only Claude-specific
behavior. If a subdirectory has its own `AGENTS.md`, read it before working in
that subtree.

## Operating Rules

1. Ask, don't assume. If intent, architecture, or requirements are unclear, ask
   before writing code.
2. Use the simplest solution that could work. Do not add abstractions,
   flexibility, or compatibility paths that were not requested.
3. Flag uncertainty explicitly. If you are not confident about a technical
   detail, say so and verify it.

General safety:

- Avoid overusing emojis.
- Never estimate implementation timelines.
- Never delete production databases or data files without explicit approval.
- Never invent technical details. Research them or say you do not know.
- Never document, validate, or reference features that are not implemented.
- Never add AI co-authorship attribution, AI badges, or watermarks.

## Done When

A change is not done until:

- Relevant tests pass, or the final response says which were not run and why.
- Lint, type-check, and formatters pass for touched files when the project has
  configured tools for them.
- New behavior has an automated test or an explicit manual-verification note.
- The final summary names changed files, commands run, and remaining risks.

## Dotfiles Ownership

Personal config lives in `~/.dotfiles` and is applied two ways:

- Symlinked files come from `packages/<pkg>/` and mirror `$HOME`.
- Nix home-manager owns the shell, several core programs, and the CLI tool set
  from `nix/home/`.

Edit the source of truth, not the deployed copy. A symlinked file should be
changed under `packages/<pkg>/`; a Nix-owned config should be changed under
`nix/home/features/<name>.nix`. Editing the generated file under `$HOME` is a
no-op for future syncs.

Before creating a new config under `$HOME`, check whether its parent is already
dotfiles-managed with `ls -la` and sibling symlinks into `~/.dotfiles`.

After editing dotfiles, re-apply with `dotfiles pull` when requested. Use
`dotfiles update` only when the user wants the slower upstream refresh.

## Code Quality

- Do not throw away or rewrite existing implementations without explicit
  permission.
- Preserve user changes and unrelated dirty work.
- Match surrounding style. Consistency within the file wins.
- Prefer functional composition over inheritance.
- Use descriptive variable names. Single-letter names are only for simple
  counters or iterators.
- Do not add deprecation comments when removing code.
- Remove old implementations entirely when replacing them, unless compatibility
  was requested.
- Do not abstract until there are three real use cases.
- Do not write tests that only assert mocked behavior.
- Do not use mocks in end-to-end tests.

Before staging, run `git status`. Never use `git add -A` or `git add .` unless
you have checked the status first.

## PRs And Commits

Write PR titles and descriptions like git commit messages. When a repo uses
squash merges, the PR title should be the commit subject and the body should
read like the commit body.

Do not include test plans, CI status, tool versions, markdown H1/H2/H3 headers,
"Verification", "Testing", "Numbers", or "Stats" sections in PR descriptions.
Use plain factual language and avoid inflated words such as critical, crucial,
essential, significant, comprehensive, robust, and elegant.

## Rule Routing

Shared coding rules live in `~/.agents/rules/` and are symlinked into
`~/.claude/rules/`. In this dotfiles repo, their tracked source is
`packages/agents/.agents/rules/`.

When a task matches a domain, read the relevant rule before implementation.
User-level path-scoped loading is unreliable, so do not depend on `paths:`
frontmatter being injected automatically.

- Python: `~/.agents/rules/python.md` for `*.py`, `*.pyi`,
  `pyproject.toml`, and `uv.lock`.
- Elixir/Phoenix: `~/.agents/rules/elixir.md` for `*.ex` and `*.exs`; add
  `ecto.md`, `phoenix.md`, `heex.md`, or `liveview.md` for schemas, repos,
  migrations, web modules, HEEx templates, LiveViews, or LiveView tests.
- Frontend: `~/.agents/rules/frontend.md` for JS, TS, CSS, HTML, Vue, and
  Svelte; add `react-nextjs.md` for React, Next.js, `app/`, `pages/`, or
  `next.config.*`.
- Go: `~/.agents/rules/go.md` for Go files and module files.
- Shell: `~/.agents/rules/shell.md` for shell scripts and shell config.
- Terraform: `~/.agents/rules/terraform.md` for Terraform/OpenTofu files.
- Secrets hygiene: `~/.agents/rules/secrets.md` when editing ignore files.

## Skill Routing

User-level skills live in `~/.agents/skills/`. In this dotfiles repo, their
tracked source is `packages/agents/.agents/skills/`.

Use a skill when the user names it or when the task clearly matches its trigger.
Before using a skill, read its `SKILL.md` completely and follow its routing for
any referenced files. Dotfiles-owned skills include:

- `event-sourcing`: design or evolve event-sourced systems.
- `simplify`: explicitly invoked cleanup pass that edits changed files directly.
- `writer-editor`: draft or revise human-facing prose; ask before file edits.

## Tools

Use Context7 proactively for current library, framework, SDK, API, CLI, or cloud
service documentation. Do not rely on memory for dependency APIs.

For the curated CLI inventory, use `CHEATSHEET.md` or run `oma`. For shell
functions and aliases, inspect `packages/shell/`. Before proposing an install,
check `packages/mise/.config/mise/config.toml`, `platform/macos/Brewfile`,
`platform/linux/packages.txt`, and `nix/home/features/packages.nix`.

Prefer the managed modern CLI tools (`rg`, `fd`, `bat`, `eza`, `dust`, `procs`,
`sd`) for local investigation. On Ubuntu, use `fdfind` in non-interactive shells
if `fd` is unavailable. Do not invoke interactive helpers such as `ff` from
non-interactive tool calls.

Use `ask` for external AI second opinions and `web` for website markdown when
needed; run each tool's `--help` before relying on less obvious options.

Shell history is managed by atuin. Do not edit `~/.zsh_history`; use
`atuin search` and `atuin history`.

## Machine-Specific Notes

Per-machine instructions live in `~/.agents/AGENTS.local.md`. This file is not
tracked and may hold host-specific details.

@~/.agents/AGENTS.local.md
