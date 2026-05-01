# Cheatsheet

Quick reference for the curated tools, aliases, functions, and keybindings in this dotfiles repo. Run `oma` from any shell to view it themed via `glow`. See [README.md](./README.md) for philosophy and install instructions.

## Modern CLI tools

Installed via `mise` (primary), Brewfile (macOS-only / system deps), or apt (Linux system deps).

| Tool         | Replaces / does                                                  |
|--------------|------------------------------------------------------------------|
| `rg`         | `grep` — recursive content search, respects `.gitignore`         |
| `fd`         | `find` — sane syntax (`fdfind` on apt; aliased to `fd`)          |
| `bat`        | `cat` with syntax highlighting (`batcat` on apt; aliased)        |
| `eza`        | `ls` with icons, git status, tree                                |
| `dust`       | `du` — visual disk-usage tree                                    |
| `procs`      | `ps` — modern, colored, sortable process listing                 |
| `sd`         | `sed` — intuitive find/replace                                   |
| `delta`      | git diff pager (auto-enabled by `.gitconfig`)                    |
| `duf`        | `df` — modern disk free                                          |
| `jq`         | JSON query/transform                                             |
| `yq`         | jq for YAML                                                      |
| `jless`      | interactive JSON pager (collapse/expand/search)                  |
| `gping`      | `ping` with a live graph                                         |
| `dog`        | `dig` — modern DNS lookup                                        |
| `mosh`       | `ssh` that survives sleep / network drops                        |
| `lazygit`    | TUI git client (stage, commit, rebase, cherry-pick, log)         |
| `lazydocker` | TUI docker client (containers, images, logs)                     |
| `atuin`      | Shell history with TUI search and optional sync                  |
| `fastfetch`  | system-info banner                                               |
| `btop`       | TUI process/resource monitor                                     |
| `glow`       | terminal markdown renderer                                       |
| `chafa`      | terminal image viewer                                            |
| `just`       | modern task runner (replaces `make` for ad-hoc tasks)            |
| `entr`       | re-run a command on file change                                  |
| `cloc`       | count lines of code, by language                                 |
| `hyperfine`  | CLI benchmarking                                                 |
| `tldr`       | simplified man pages                                             |
| `zoxide`     | `cd` with frecency (`z foo`, `zi` for fuzzy)                     |
| `fzf`        | fuzzy finder (Ctrl+R, Ctrl+T, Alt+C, plus `ff`)                  |
| `gh`         | GitHub CLI, also wired as git credential helper                  |

## Aliases

From [`packages/shell/.aliases`](./packages/shell/.aliases). All work in zsh and bash.

| Alias          | Expands to                                              |
|----------------|---------------------------------------------------------|
| `..`           | `cd ..`                                                 |
| `...`          | `cd ../..`                                              |
| `....`         | `cd ../../..`                                           |
| `ll`           | `eza -la --git --icons --group-directories-first`       |
| `la`           | `eza -a --icons`                                        |
| `l`            | `eza -F --icons`                                        |
| `ltree`        | `eza --tree --level=2 --icons`                          |
| `g`            | `git`                                                   |
| `ga`, `gaa`    | `git add`, `git add --all`                              |
| `gb`, `gba`    | `git branch`, `git branch -a`                           |
| `gc`, `gcmsg`  | `git commit`, `git commit -m`                           |
| `gco`, `gcb`   | `git checkout`, `git checkout -b`                       |
| `gd`, `gds`    | `git diff`, `git diff --staged`                         |
| `gst`, `gsta`  | `git status`, `git stash`                               |
| `gp`, `gpom`   | `git push`, `git pull origin main`                      |
| `glg`, `glog`  | pretty git log graphs                                   |
| `gf`, `gl`     | `git fetch`, `git pull`                                 |
| `grb`, `grh`   | `git rebase`, `git reset HEAD`                          |
| `lg`           | `lazygit`                                               |
| `lzd`          | `lazydocker` (`ld` is the GNU linker, kept clear)       |
| `oma`          | `glow ~/.dotfiles/CHEATSHEET.md` (this page, themed)    |
| `cc`           | `claude` (Claude Code CLI)                              |
| `nr`           | `npm run`                                               |
| `c`            | `clear`                                                 |
| `h`            | `history`                                               |

## Shell functions

From [`packages/shell/.aliases`](./packages/shell/.aliases) and [`packages/shell/.functions`](./packages/shell/.functions).

| Function                         | What it does                                                 |
|----------------------------------|--------------------------------------------------------------|
| `ff`                             | fuzzy file finder; opens selection in `$EDITOR` (vim)        |
| `ccc`                            | AI-drafted git commit (uses `claude -p`); flags related unstaged files |
| `dotfiles cd`                    | `cd ~/.dotfiles`                                             |
| `light` / `dark`                 | switch ghostty / bat / fzf / tmux / claude themes live       |
| `compress <path>`                | create `<path>.tar.gz`                                       |
| `decompress <archive>`           | expand tar.gz, tgz, tar.bz2, tar.xz, tar, zip, gz, bz2, xz   |
| `img2jpg <input>`                | near-full-quality JPG (`-quality 92`)                        |
| `img2jpg-small <input>`          | JPG capped at 1920×1080                                      |
| `img2jpg-medium <input>`         | JPG capped at 3200×1800                                      |
| `img2png <input>`                | compressed-but-lossless PNG                                  |
| `transcode-video-1080p <input>`  | H.264 1080p MP4, AAC 192k                                    |
| `transcode-video-4K <input>`     | H.264 4K MP4, AAC 256k                                       |
| `fip <host> <port>...`           | forward remote port(s) to localhost via `ssh -fN`            |
| `dip <port>...`                  | disconnect a forwarded port                                  |
| `lip`                            | list active ssh port forwards                                |
| `try [name]`                     | cd into `~/Work/tries/YYYY-MM-DD[-name]` (creates if missing)|

## Keybindings

### Zsh

| Key                | Action                                                     |
|--------------------|------------------------------------------------------------|
| `Tab`              | fzf-tab fuzzy completion (with previews)                   |
| `Ctrl+R`           | atuin TUI history search                                   |
| `Ctrl+T`           | fzf file picker (paste path)                               |
| `Alt+C`            | fzf cd into directory                                      |
| `Up` / `Down`      | prefix history search (preserved; atuin doesn't take Up)   |

### Tmux (prefix `Ctrl+a`)

| Key                | Action                                                     |
|--------------------|------------------------------------------------------------|
| `prefix r`         | reload `~/.tmux.conf`                                      |
| `prefix "` / `%`   | split horizontal / vertical (inheriting cwd)               |
| `prefix - / _`     | split horizontal / vertical (alternates)                   |
| `prefix h/j/k/l`   | move between panes (vim-style)                             |
| `prefix H/J/K/L`   | resize pane (repeatable)                                   |
| `prefix Ctrl+h/l`  | previous / next window                                     |
| `prefix Enter`     | enter copy mode                                            |
| `v` (copy-mode)    | begin selection                                            |
| `y` (copy-mode)    | copy + cancel (also at prefix: copy buffer to clipboard)   |
| `prefix p` / `P`   | paste / choose buffer                                      |

### Lazygit (in any repo)

`?` shows the help overlay. Common flow: `Space` to stage, `c` to commit, `P` to push, `enter` to drill into a file's diff.

## Themes

The repo ships a live light/dark switcher:

```sh
dark      # Catppuccin Mocha across ghostty, bat, fzf, tmux, claude
light     # GitHub Light High Contrast across the same
```

Behind the scenes, these write the theme line into `~/.config/ghostty/config` (a `git smudge`/`clean` filter keeps the working tree clean) and update `BAT_THEME`, `FZF_DEFAULT_OPTS`, the tmux source file, and the Claude Code config.

## One-time setup

After the first `~/.dotfiles/install.sh`:

1. **GitHub CLI** — `gh auth login`. Wires up `git` credentials too.
2. **atuin** — already imports `~/.zsh_history` once. To opt into cloud sync: `atuin register -u <username> -e <email>` then `atuin sync`.
3. **mise tools** — `mise install` if any tool didn't install on first run (rare). Re-run `dotfiles sync` to retry the manifest.
4. **Secrets** — write API keys to `~/.secrets`; sourced by both shells.
5. **Set zsh as default shell** — install.sh prompts; otherwise `chsh -s "$(command -v zsh)"`.
6. **lima only** — verify ghostty picked up "JetBrainsMono Nerd Font Mono" (Settings → Font, or check `font-family` in `~/.config/ghostty/config`).

## Verifying the toolkit

```sh
for t in lazygit lazydocker fastfetch atuin dust procs sd gping dog mosh \
         yq jless just entr cloc glow chafa rg fd bat eza zoxide fzf; do
  command -v "$t" >/dev/null && printf "ok    %s\n" "$t" || printf "MISS  %s\n" "$t"
done

# Functions
type ff compress decompress img2jpg fip dip lip try
```

## Troubleshooting

- **"command not found: lazygit"** etc. — run `mise install` then open a new shell. If it still fails, check `mise ls` for the failing tool and look at `~/.local/state/mise/log/`.
- **fzf-tab Tab not working** — `~/.zsh/plugins/fzf-tab/` missing. Re-run `~/.dotfiles/install.sh` or `git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/plugins/fzf-tab`.
- **atuin Ctrl+R not popping up** — `command -v atuin` to verify install. Then `atuin status`. The history db lives at `~/.local/share/atuin/history.db`.
- **Icons render as boxes** — Nerd Font missing. lima: `brew install --cask font-jetbrains-mono-nerd-font`, then restart ghostty.
