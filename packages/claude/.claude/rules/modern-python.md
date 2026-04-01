---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/pyproject.toml"
  - "**/uv.lock"
---

## Modern Python tooling

Source: github.com/trailofbits/skills/tree/main/plugins/modern-python

### Required tools

| Tool | Purpose | Replaces |
|------|---------|----------|
| **uv** | Package/project management | pip, virtualenv, pip-tools, pipx, pyenv, poetry |
| **ruff** | Linting AND formatting | flake8, black, isort, pyupgrade |
| **ty** | Type checking | mypy, pyright |

No exceptions. Never use pip, poetry, pipenv, black, isort, mypy, or pyright.

### uv gotchas

- **`uv add` not `uv pip install`** -- `uv pip` is the legacy compatibility interface. ALWAYS use `uv add`/`uv remove` for dependency management.
- **Never manually edit `dependencies` in pyproject.toml** -- use `uv add <pkg>` / `uv remove <pkg>`.
- **Never manually activate virtualenvs** -- use `uv run <cmd>` for everything.
- **`uv sync --frozen`** in CI for reproducible builds.
- **`UV_PROJECT_ENVIRONMENT=.venv-dev`** when developing on host while also running in containers, so host and container venvs don't collide.

### ruff config

Always enable isort rules (`I`) in ruff config. Recommended starter:

    [tool.ruff.lint]
    select = ["ALL"]
    ignore = ["D", "COM812", "ISC001"]

    [tool.ruff.lint.per-file-ignores]
    "tests/**/*.py" = ["S101", "PLR2004", "ANN"]

### ty config

**WRONG:** `[tool.ty]` python-version
**CORRECT:** `[tool.ty.environment]` python-version

    [tool.ty.environment]
    python-version = "3.11"

    [tool.ty.terminal]
    error-on-warning = true

### Dependency groups (PEP 735)

Use `[dependency-groups]` for dev/test/docs dependencies, **not** `[project.optional-dependencies]`. The latter is for optional runtime features users install (`pip install mylib[postgres]`).

    [dependency-groups]
    dev = [{include-group = "lint"}, {include-group = "test"}]
    lint = ["ruff", "ty"]
    test = ["pytest", "pytest-cov"]

### Build backend

Use `uv_build` instead of hatchling/setuptools for most projects:

    [build-system]
    requires = ["uv_build>=0.9,<1"]
    build-backend = "uv_build"

### PEP 723 for standalone scripts

Single-file scripts with dependencies use inline metadata, not requirements.txt:

    # /// script
    # requires-python = ">=3.11"
    # dependencies = ["requests", "rich"]
    # ///

Run with `uv run script.py` -- dependencies auto-install.

### uv.lock in version control

- **Applications**: commit `uv.lock` (reproducible deploys)
- **Libraries**: gitignore `uv.lock` (users resolve their own deps)
