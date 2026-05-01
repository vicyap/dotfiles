# CLI Tools

Modern CLI tools are installed on both lima (macOS) and rhinestone (Linux) via mise / Brewfile / apt. The full inventory is in `~/.agents/AGENTS.md` under "CLI tools available". Some Claude-specific notes:

## In Bash invocations, prefer modern tools

When generating shell commands, default to:

- `rg` over `grep` (faster, smarter defaults, ignores `.gitignore`)
- `fd` over `find` (saner syntax — `fd <pattern>` not `find . -name '*pattern*'`). On Ubuntu apt the binary is `fdfind`; the dotfiles alias maps `fd` to it.
- `bat` over `cat` for syntax-highlighted viewing (or `batcat` on Linux). When piping, use `bat -p --color=always` to keep highlighting.
- `dust` over `du`, `procs` over `ps`, `sd` over `sed` for one-off shell tasks. (For scripts that target other machines, stick with POSIX sed.)
- `delta` is wired into `.gitconfig` — `git diff` and `git log -p` already render through delta. Don't pipe through `cat` or `less` — that strips colors.
- `jq` for JSON, `yq` for YAML, `jless` for interactive JSON pagination.
- `eza` over `ls` (the `ls` shell function in `~/.aliases` already wraps eza).

## Don't propose installs

All of these tools are managed declaratively. Before suggesting `brew install …` or `apt install …`, check:

- `~/.dotfiles/packages/mise/.config/mise/config.toml` (the primary path)
- `~/.dotfiles/platform/macos/Brewfile`
- `~/.dotfiles/platform/linux/packages.txt`

If a tool is already there, the user just needs to run `dotfiles sync` (or `mise install`). If it's not, propose adding it to mise first, brew/apt only when mise can't manage it.

## Use the custom shell functions

These exist in `~/.functions` and are useful in Bash one-liners:

- `ff` — interactive fuzzy file picker that opens vim. Don't replicate it.
- `compress` / `decompress` — tar wrappers.
- `try <name>` — date-stamped scratch dir under `~/Work/tries`.
- `fip` / `dip` / `lip` — SSH port forwarding.

For `ff` specifically: it's interactive (TUI), so don't invoke it from non-interactive Bash tool calls. Use `fd` or `fzf` directly when you need automation.

## atuin replaces Ctrl+R

The user's shell history lives in atuin's database (`~/.local/share/atuin/history.db`), not just `~/.zsh_history`. Don't suggest editing `~/.zsh_history` directly to clean up history — point them to `atuin` commands instead (`atuin search`, `atuin history`).
