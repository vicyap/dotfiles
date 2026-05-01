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
│   └── skills/                # Universal agent skills
├── .claude/
│   ├── skills -> ../.agents/skills  # Symlink to universal skills
│   └── rules/                 # Claude Code path-scoped rules
└── subdirectory/
    ├── AGENTS.md              # Subdirectory-scoped shared instructions
    └── CLAUDE.md              # @AGENTS.md + Claude Code specifics
```

AGENTS.md is the single source of truth at each level. Agent-specific files import it and add only agent-specific overrides.

Every CLAUDE.md starts with `@AGENTS.md`:

```markdown
@AGENTS.md

# Claude Code

Agent-specific instructions here (or omit this section if none).
```

Subdirectories can have their own AGENTS.md + CLAUDE.md pairs for progressive disclosure.

---

## General

* When uncertain, ask clarifying questions.
* Avoid overuse of emojis.
* NEVER estimate implementation timelines.
* NEVER delete production databases or data files without explicit approval. Offer non-destructive alternatives first.

## Dotfiles

My personal config lives in `~/.dotfiles` with per-file symlinks into `$HOME`, created by `~/.dotfiles/install.sh` (see `~/.dotfiles/lib/symlink.sh`).

* When modifying files under `~/.claude/`, `~/.agents/`, `~/.config/`, etc., always edit through `~/.dotfiles/packages/<pkg>/`. Editing an existing symlinked target flows through automatically; new files must be created under `~/.dotfiles/packages/<pkg>/` first, then symlinked back (or re-run `~/.dotfiles/install.sh`).
* Before creating a new config file under `$HOME`, check whether its parent directory is dotfiles-managed — `ls -la` for sibling symlinks pointing into `~/.dotfiles` is the quickest tell.

## PRs and Commits

* Write PR titles and descriptions like git commit messages. Skip test plans.
* For `usetemi/` repos, PRs are always squash-merged. Write the PR title as the commit subject and the description as the commit body -- the result should read as a single well-formed commit message.
* Don't include meta-commentary (test counts, CI status, tool versions) in commit messages or PR descriptions.
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

These are installed across both lima (macOS) and rhinestone (Linux) via the dotfiles manifests. Prefer them over their classic equivalents:

| Tool        | Replaces / does                              |
|-------------|----------------------------------------------|
| `rg`        | `grep` (recursive content search)            |
| `fd`        | `find` (`fdfind` on Linux apt)               |
| `bat`       | `cat` with syntax highlighting (`batcat` on Linux apt) |
| `eza`       | `ls` (icons, git status, tree)               |
| `dust`      | `du` (visual disk usage)                     |
| `procs`     | `ps` (modern, colored, sortable)             |
| `sd`        | `sed` (intuitive find/replace)               |
| `delta`     | `git diff` pager (configured in `.gitconfig`)|
| `duf`       | `df` (disk free)                             |
| `jq`        | JSON query/transform                         |
| `yq`        | YAML query (jq for YAML)                     |
| `jless`     | Interactive JSON pager                       |
| `gping`     | `ping` with graph                            |
| `dog`       | `dig` (modern DNS lookup)                    |
| `mosh`      | `ssh` (mobile-resilient; recovers tunnels)   |
| `lazygit`   | TUI git client                               |
| `lazydocker`| TUI docker client                            |
| `atuin`     | Shell history (Ctrl+R = TUI search)          |
| `fastfetch` | System info banner                           |
| `btop`      | TUI process/resource monitor                 |
| `glow`      | Markdown renderer                            |
| `chafa`     | Terminal image viewer                        |
| `just`      | Modern task runner (Makefile alternative)    |
| `entr`      | Re-run a command on file change              |
| `cloc`      | Count lines of code by language              |
| `hyperfine` | CLI benchmark tool                           |
| `tldr`      | Simplified man pages                         |
| `zoxide`    | `cd` with frecency (`z`, `zi`)               |
| `fzf`       | Fuzzy finder (Ctrl+R, Ctrl+T, Alt+C, `ff`)   |
| `gh`        | GitHub CLI (also git credential helper)      |

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
| `try [name]`                            | cd into `~/Work/tries/YYYY-MM-DD-name` (creates if missing)|
| `light` / `dark`                        | switch ghostty/bat/fzf/tmux/claude themes live             |

Don't propose installing tools that already appear above — they're managed via `mise` (`packages/mise/.config/mise/config.toml`), Brewfile, or apt manifest.
