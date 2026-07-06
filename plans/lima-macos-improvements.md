# lima / macOS Improvements — July 2026 audit

Items from the dotfiles audit that only apply to lima (or can only be verified
there). Everything here is unapplied; run through it on lima. Shared fixes
already committed on main (compinit caching, tmux extended-keys, mise
hook_env, atuin daemon-fuzzy, etc.) arrive with the next `dotfiles pull`.

## 1. Ghostty: native light/dark switching (medium)

Ghostty's `theme` key now natively supports OS-driven switching:

```
theme = light:<light theme>,dark:Catppuccin Mocha
```

Today the `light`/`dark` shell functions sed-rewrite the live ghostty config,
and `nix/home/features/git.nix` carries a `filter.ghostty-theme` clean/smudge
pair purely to hide those runtime edits from git. Adopting the native syntax
deletes the sed branch in `packages/zsh/.zsh/theme.zsh` and the whole git
filter.

Steps on lima:
1. `ghostty +list-themes` and pick the light theme (the audit suggested
   "GitHub Light High Contrast" — verify the exact name exists).
2. Set `theme = light:<name>,dark:Catppuccin Mocha` in
   `packages/ghostty/.config/ghostty/config`; reload and toggle
   System Settings → Appearance to confirm it follows.
3. Trade-off to decide first: ghostty then follows the OS, not the shell
   `light`/`dark` commands — the rest of the stack (bat/fzf/tmux/vim) stays
   shell-driven. If acceptable, remove the ghostty branch from theme.zsh and
   the clean/smudge filter from git.nix + .gitattributes.

## 2. Nix GC / generation expiry (high) — APPLIED 2026-07-06

Configured in `nix/home/hosts/lima.nix` as home-manager `nix.gc` (weekly
launchd agent, `--delete-older-than 30d`), not nix-darwin's `nix.gc`:
`nix/darwin/common.nix` sets `nix.enable = false` (the upstream installer owns
the daemon), which makes nix-darwin's nix.* options unavailable. The
home-manager agent runs as the user, which also expires the user's old
profile generations (home-manager included) before collecting — the darwin
counterpart of rhinestone's `services.home-manager.autoExpire`.

Verify on lima after `dotfiles pull` + new login:
`launchctl list | grep nix-gc` (user domain, not sudo).

## 3. mise binary currency (low)

mise on macOS is brew-owned, so `brew bundle` (already in refresh_upstream)
keeps it current — confirm `which mise` is the brew one and that the Brewfile
still lists it. The Linux-side `mise self-update` recommendation (see the main
audit report) must stay conditional so it never runs against a brew-owned
binary.

## 4. Verify shared fixes landed (5 min)

After `dotfiles pull` on lima:
- `hyperfine 'zsh -i -c exit'` — expect a drop from the `compinit -C` caching
  (Apple's /etc/zshrc has no Ubuntu-style double-compinit gate, so the
  `skip_global_compinit` half is inert there; the completionInit half is not).
- `zsh -ic 'bindkey "^I"'` → `fzf-tab-complete` still bound.
- New tmux panes get `history-limit 100000` / `extended-keys on`
  (`tmux show -g history-limit extended-keys`, new session).
- `atuin doctor` still healthy with `search_mode = daemon-fuzzy`.
