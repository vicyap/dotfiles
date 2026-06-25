# tmux — native home-manager module. Replaces the TPM-cloned plugins with
# nixpkgs tmuxPlugins (resurrect + continuum) and generates the config from the
# hand-tuned .tmux.conf. home-manager writes ~/.config/tmux/tmux.conf.
#
# Runtime state is NOT managed by Nix: resurrect/continuum save trees under
# ~/.tmux/resurrect/ are left untouched, and the tmux-status Go binary is still
# built by the mise `setup:tmux-status` task into ~/.local/bin/tmux-status.
#
# The theme files (~/.tmux/themes/{dark,light}.conf) are placed read-only so the
# `light`/`dark` switcher's `tmux source-file ~/.tmux/themes/${mode}.conf` works.
{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    escapeTime = 10;
    historyLimit = 1000000;
    terminal = "tmux-256color";
    # The config is hand-tuned; don't layer tmux-sensible on top.
    sensibleOnTop = false;
    # Keep the socket at the default /tmp/tmux-$UID. home-manager's default
    # (secureSocket = true) sets TMUX_TMPDIR to $XDG_RUNTIME_DIR (/run/user/$UID),
    # which is cleaned on last-session logout — that would orphan the always-on
    # server on rhinestone and break "close the laptop, resume the session".
    secureSocket = false;

    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-processes '"~claude->claude" "~npm run dev->npm run dev"'
        '';
      }
      {
        # continuum must load after resurrect (it depends on it).
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      # Settings the module options don't cover. (baseIndex already sets both
      # base-index and pane-base-index; keyMode already sets mode-keys +
      # status-keys, so those are intentionally not repeated here.)
      set -g renumber-windows on
      set -g repeat-time 400
      # focus-events: the module defaults this off; the old config wants it on.
      set -g focus-events on

      # True color + ghostty passthrough
      set -as terminal-overrides ",xterm-ghostty:RGB"
      set -as terminal-features ",xterm-ghostty:hyperlinks"
      set -g allow-passthrough on

      # OSC 52 clipboard (copy to local clipboard over SSH). Works everywhere,
      # including headless rhinestone — no copy binary needed. The macOS-only
      # `copy-command 'pbcopy'` and prefix `y` save-buffer binding live in
      # nix/home/hosts/lima.nix (pbcopy does not exist on Linux).
      set -g set-clipboard on

      unbind -Tcopy-mode-vi MouseDragEnd1Pane

      # Vi copy bindings
      bind -Tcopy-mode-vi v send -X begin-selection
      bind -Tcopy-mode-vi y send -X copy-selection-and-cancel
      bind Enter copy-mode
      bind p paste-buffer -p
      bind P choose-buffer

      # Pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Window navigation
      bind -r C-h previous-window
      bind -r C-l next-window
      bind -n M-h previous-window
      bind -n M-l next-window

      # Pane resize
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

      # New panes inherit working directory
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind _ split-window -h -c "#{pane_current_path}"

      # Status line
      set -g status-interval 1
      set -g status-left-length 30
      set -g status-right-length 160
      set -g monitor-activity on
      set -g visual-activity off

      # Theme (colors, status bar) -- switched live by `dark`/`light`
      source-file ~/.tmux/themes/dark.conf

      # Machine-local overrides (optional)
      source -q ~/.tmux.conf.local
    '';
  };

  # Read-only theme files for the live switcher; never mutated at runtime.
  home.file.".tmux/themes/dark.conf".source =
    ../../../packages/tmux/.tmux/themes/dark.conf;
  home.file.".tmux/themes/light.conf".source =
    ../../../packages/tmux/.tmux/themes/light.conf;
}
