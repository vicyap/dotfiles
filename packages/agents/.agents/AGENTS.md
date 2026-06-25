# Personal Agent Instructions

These instructions apply to all AI coding agents.

## Who Am I

I am Victor Yap.

## Per-Project Convention

```
project/
├── AGENTS.md                  # Shared instructions (all agents read this)
├── CLAUDE.md                  # @AGENTS.md + Claude Code specifics
├── .agents/
│   ├── rules/                 # Shared path/domain-scoped coding rules
│   └── skills/                # Universal agent skills
├── .claude/
│   ├── rules/                 # Per-file symlinks into ../.agents/rules
│   └── skills -> ../.agents/skills  # Symlink to universal skills
└── subdirectory/
    ├── AGENTS.md              # Subdirectory-scoped shared instructions
    └── CLAUDE.md              # @AGENTS.md + Claude Code specifics
```

AGENTS.md is the single source of truth at each level.

Every CLAUDE.md starts with `@AGENTS.md`:

```markdown
@AGENTS.md

# Claude Code

Claude Code specific instructions here (or omit this section if none).
```

Follow progressive disclosure: Subdirectories have their own AGENTS.md + CLAUDE.md pairs.

---

## Very Important

1. Ask, don't assume. If something is unclear, ask before writing a single line. Never make silent assumptions about intent, architecture, or requirements.
2. Simplest solution first. Always implement the simplest thing that could work. Do not add abstractions or flexibility that weren't explicitly requested.
3. Flag uncertainty explicitly. If you are not confident about an approach or technical detail, say so before proceeding. Confidence without certainty causes more damage than admitting a gap.

## General

* Avoid overuse of emojis.
* NEVER estimate implementation timelines.
* NEVER delete production databases or data files without explicit approval. Offer non-destructive alternatives first.

## Done When

A change isn't done until:

* Relevant tests pass, or the final response says which were not run and why.
* Lint, type-check, and formatters pass for the files you touched (run the project's configured tools).
* New behavior has an automated test or an explicit manual-verification note.
* The final summary names the changed files, the commands you ran, and any remaining risks.

## Dotfiles

Personal config lives in `~/.dotfiles`, applied two ways: per-file symlinks from `packages/<pkg>/` into `$HOME`, and Nix home-manager (`nix/home/`), which owns the shell, several core programs, and the CLI tool set rather than symlinking them. After editing, re-apply with `dotfiles pull` (fast); `dotfiles update` adds the expensive upstream refresh. Check `~/.dotfiles` (its `AGENTS.md`, `lib/symlink.sh`) when you need to know which mechanism owns a file.

* Edit the source of truth, not the deployed copy: a symlinked file under `packages/<pkg>/` flows through automatically, but a Nix-owned config must be changed at `nix/home/features/<name>.nix` — editing it in `$HOME` is a no-op.
* Before creating a new config under `$HOME`, check whether its parent is dotfiles-managed — `ls -la` for sibling symlinks into `~/.dotfiles` is the quickest tell (Nix-owned areas won't show one).

## PRs and Commits

* Write PR titles and descriptions like git commit messages. Skip test plans.
* For `usetemi/` repos, PRs are always squash-merged. Write the PR title as the commit subject and the description as the commit body -- the result should read as a single well-formed commit message.
* Don't include meta-commentary (test counts, CI status, tool versions) in commit messages or PR descriptions.
* Specifically forbidden in PR bodies: markdown H1/H2/H3 headers (`#`, `##`, `###`), "Verification" / "Testing" / "Numbers" / "Stats" sections, anything that wouldn't survive a squash. Plain paragraphs and `-` bullets only. Before submitting, ask: "Would I want this verbatim as the next squashed commit?" If not, strip it.
* NEVER add AI co-authorship attribution to commit messages.
* NEVER add AI-generated badges or watermarks to PR descriptions.
* Use plain, factual language. Avoid inflated words: critical, crucial, essential, significant, comprehensive, robust, elegant.

## Anti-Hallucination

Sources: github.com/obra/dotfiles, github.com/trailofbits/claude-code-config

* NEVER invent technical details. If you don't know something -- research it or say so. Do not fabricate.
* NEVER document, validate, or reference features that aren't implemented.

## Code Quality

* NEVER throw away or rewrite existing implementations without explicit permission.
* NEVER use `git add -A` or `git add .` without running `git status` first.
* Match the style of surrounding code. Consistency within a file trumps external standards.
* Complete all workflow steps (review, test, verify) even for small changes.
* Don't abandon a working repetitive approach mid-task.
* When replacing an implementation, remove the old one entirely. No backward-compatible shims unless requested.

## Testing

* NEVER write tests that assert mocked behavior. Tests that assert a mock returns what it was configured to return are worthless.
* NEVER implement mocks in end-to-end tests. E2E tests use real data and real APIs.

## Code Style

* Prefer functional composition over object-oriented inheritance.
* Use descriptive variable names. No single-letter names except counters/iterators.
* No abbreviated variable names unless widely recognized (e.g., `id`, `url`, `html`).
* No deprecation comments when removing code.
* Simplicity over backwards compatibility: use modern language features, remove deprecated code paths.
* Rule of Three: don't abstract until you have 3 use cases.

## Code Rules

Shared coding rules live in `~/.agents/rules/` (symlinked into `~/.claude/rules/`).
When working in a matching domain, READ the relevant rule file before implementing
changes — treat that as the contract for every agent. Path-scoped auto-loading via
the `paths:` frontmatter is unreliable for user-level rules, so don't depend on a
rule being injected automatically; open it yourself when its domain applies.

* Python: `~/.agents/rules/python.md` for `*.py`, `*.pyi`, `pyproject.toml`, and `uv.lock`.
* Elixir/Phoenix: `~/.agents/rules/elixir.md` for `*.ex` and `*.exs`; add `ecto.md`, `phoenix.md`, `heex.md`, or `liveview.md` when working in schemas, repos, migrations, web modules, HEEx templates, LiveViews, or LiveView tests.
* Frontend: `~/.agents/rules/frontend.md` for JS, TS, CSS, HTML, Vue, and Svelte; add `react-nextjs.md` for React, Next.js, `app/`, `pages/`, or `next.config.*`.
* Go: `~/.agents/rules/go.md` for Go files and module files.
* Shell: `~/.agents/rules/shell.md` for shell scripts and shell config.
* Terraform: `~/.agents/rules/terraform.md` for Terraform/OpenTofu files.
* Secrets hygiene: `~/.agents/rules/secrets.md` when editing ignore files.

## Tools

### Context7

Proactively look up library/framework documentation when working with external dependencies. Don't rely on training data for API details.

### ask

Query external AI models for second opinions or brainstorming. Run `ask --help` for usage.

```bash
ask -Q -o "is there a simpler way to implement X"
ask -Q -o -f src/main.py "suggest improvements"
git diff | ask -Q -o "review this diff"
```

### web

Get markdown from websites. Run `web --help` for usage.

```bash
web https://example.com
web https://example.com --truncate-after 5000
```

### CLI tools available

The curated toolkit (modern CLI replacements like `rg`/`fd`/`bat`/`eza`/`dust`/`procs`/`sd`, plus TUIs and data tools) is installed across both lima (macOS) and rhinestone (Linux). See [`CHEATSHEET.md`](https://github.com/vicyap/dotfiles/blob/main/CHEATSHEET.md) (or run `oma`) for the full list and what each replaces. Prefer these over their classic equivalents.

Tool usage rules:

* Prefer the modern tools above in generated commands and local investigation (`rg`, `fd`, `bat`, `eza`, `dust`, `procs`, `sd`) unless portability requires classic POSIX tools.
* On Ubuntu apt, `fd` may be installed as `fdfind`; use `fdfind` in non-interactive shells if `fd` is unavailable.
* When piping `bat`, use `bat -p --color=always` to keep highlighting.
* `delta` is already wired into `.gitconfig`; don't pipe `git diff` or `git log -p` through `cat` or `less`.
* Before proposing an install, check `~/.dotfiles/packages/mise/.config/mise/config.toml`, `~/.dotfiles/platform/macos/Brewfile`, and `~/.dotfiles/platform/linux/packages.txt`. If a tool is already managed there, use `dotfiles sync` or `mise install`.
* If a missing tool is worth adding, prefer adding it through mise first; use Brewfile or apt only when mise cannot manage it.
* Shell history is managed by atuin. Don't edit `~/.zsh_history` directly to clean history; use `atuin search` and `atuin history`.

### Custom shell functions

Sourced from `~/.aliases` and `~/.functions` (see `packages/shell/`):

| Function                                | Description                                                |
|-----------------------------------------|------------------------------------------------------------|
| `ff`                                    | fuzzy file finder, opens selection in `$EDITOR` (vim)      |
| `ccc`                                   | AI-driven git commit (uses `claude -p`)                    |
| `compress <path>`                       | create `<path>.tar.gz`                                     |
| `decompress <archive>`                  | expand tar.gz/tgz/tar.bz2/tar.xz/tar/zip/gz/bz2/xz         |
| `img2jpg`, `img2jpg-{small,medium}`     | convert image to JPG (full / 1080p / 1800p)                |
| `img2png`                               | convert image to compressed-but-lossless PNG               |
| `transcode-video-{1080p,4K}`            | ffmpeg H.264 transcode with sane defaults                  |
| `fip <host> <port>...`                  | forward remote port to localhost via `ssh -fN`             |
| `dip <port>...`                         | disconnect a forwarded port                                |
| `lip`                                   | list active ssh port forwards                              |
| `try [name]`                            | cd into `${TMPDIR:-/tmp}/tries/YYYY-MM-DD-name` (creates if missing)|
| `light` / `dark`                        | switch ghostty/bat/fzf/tmux/claude themes live             |

`ff` is interactive, so don't invoke it from non-interactive tool calls. Use `fd`
or `fzf` directly when automation needs file discovery.

## Machine-Specific Notes

Per-machine instructions live in `~/.agents/AGENTS.local.md` — not tracked by git
(it holds host-specific details), and scaffolded as an empty file if absent so
this import always resolves.

@~/.agents/AGENTS.local.md
