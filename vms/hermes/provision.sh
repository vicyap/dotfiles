#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

apt-get update
apt-get install -y \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  dbus-x11 \
  fd-find \
  ffmpeg \
  fonts-liberation \
  fonts-noto-color-emoji \
  git \
  jq \
  libasound2t64 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libcairo2 \
  libcups2 \
  libdrm2 \
  libgbm1 \
  libgtk-3-0 \
  libnss3 \
  libpango-1.0-0 \
  libx11-xcb1 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxkbcommon0 \
  libxrandr2 \
  pkg-config \
  python3-dev \
  qrencode \
  ripgrep \
  rsync \
  tmux \
  unzip \
  vim \
  wget \
  x11-utils \
  xauth \
  xvfb \
  zsh

java_version="25"
java_home="/opt/jre-${java_version}"
if [ ! -x "${java_home}/bin/java" ]; then
  java_tmp="$(mktemp -d)"
  curl -fsSL "https://api.adoptium.net/v3/binary/latest/${java_version}/ga/linux/x64/jre/hotspot/normal/eclipse" \
    -o "$java_tmp/jre.tar.gz"
  rm -rf "$java_home"
  mkdir -p "$java_home"
  tar -xzf "$java_tmp/jre.tar.gz" -C "$java_home" --strip-components=1
  rm -rf "$java_tmp"
  ln -sfn "${java_home}/bin/java" /usr/local/bin/java
fi

signal_cli_version="0.14.3"
signal_cli_home="/opt/signal-cli-${signal_cli_version}"
signal_cli_url="https://github.com/AsamK/signal-cli/releases/download/v${signal_cli_version}/signal-cli-${signal_cli_version}.tar.gz"
if [ ! -x "${signal_cli_home}/bin/signal-cli" ] ||
  [ "$("${signal_cli_home}/bin/signal-cli" --version 2>/dev/null)" != "signal-cli ${signal_cli_version}" ]; then
  signal_cli_tmp="$(mktemp -d)"
  curl -fsSL "$signal_cli_url" -o "$signal_cli_tmp/signal-cli.tar.gz"
  rm -rf "$signal_cli_home"
  tar -xzf "$signal_cli_tmp/signal-cli.tar.gz" -C /opt
  rm -rf "$signal_cli_tmp"
fi
ln -sfn "${signal_cli_home}/bin/signal-cli" /usr/local/bin/signal-cli

install -d -o vagrant -g vagrant /home/vagrant/workspace
install -d -o vagrant -g vagrant /home/vagrant/.cache
install -d -o vagrant -g vagrant /home/vagrant/.config
install -d -o vagrant -g vagrant /home/vagrant/.local/bin
install -d -o vagrant -g vagrant /home/vagrant/.local/share
install -d -o vagrant -g vagrant /home/vagrant/.local/state
chown -R vagrant:vagrant /home/vagrant/.cache /home/vagrant/.config /home/vagrant/.local

install -d -o vagrant -g vagrant /home/vagrant/.config/systemd/user
cat >/home/vagrant/.config/systemd/user/signal-cli.service <<'SERVICE'
[Unit]
Description=signal-cli HTTP daemon
Documentation=https://github.com/AsamK/signal-cli
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=%h/.config/signal-cli/daemon.env
ExecStart=/usr/local/bin/signal-cli --account ${SIGNAL_CLI_ACCOUNT} daemon --http ${SIGNAL_CLI_HTTP}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
SERVICE
chown vagrant:vagrant /home/vagrant/.config/systemd/user/signal-cli.service
loginctl enable-linger vagrant

sudo -H -u vagrant bash -lc '
  set -e

  systemctl --user daemon-reload
  if [ -f "$HOME/.config/signal-cli/daemon.env" ]; then
    systemctl --user enable --now signal-cli.service
  fi
'

profile_path_line="export PATH=\"\$HOME/.local/bin:\$PATH\""
grep -qxF "$profile_path_line" /home/vagrant/.profile ||
  printf '%s\n' "$profile_path_line" >>/home/vagrant/.profile

cat >/home/vagrant/.zshenv <<'PROFILE'
export PATH="$HOME/.local/bin:$PATH"
PROFILE
chown vagrant:vagrant /home/vagrant/.profile /home/vagrant/.zshenv

if [ -x /usr/bin/zsh ]; then
  chsh -s /usr/bin/zsh vagrant || true
fi

sudo -H -u vagrant bash -lc '
  set -e

  if [ ! -x "$HOME/.local/bin/hermes" ]; then
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh |
      bash -s -- --skip-setup
  else
    "$HOME/.local/bin/hermes" update || true
  fi
'

sudo -H -u vagrant bash -lc '
  set -e

  if command -v xvfb-run >/dev/null 2>&1; then
    xvfb-run -a xdpyinfo >/dev/null
  fi
'

cat >/etc/profile.d/hermes.sh <<'PROFILE'
export PATH="$HOME/.local/bin:$PATH"
PROFILE
