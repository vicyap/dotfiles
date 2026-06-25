---
description: Shell script quality checks (bash, sh, zsh scripts). Loaded unconditionally — user-level path-scoping is unreliable in Claude Code, and this is small + broadly relevant.
---

# Shell Scripts

When writing or modifying shell scripts, always run these before considering the work done:

- **shellcheck** — lint all changed `.sh` files. Fix all warnings.
- **shfmt** — format all changed `.sh` files (`shfmt -w -i 4 -bn -ci`).
