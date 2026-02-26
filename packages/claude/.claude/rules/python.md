# Python Tooling

Always use these tools for Python work. No exceptions.

- **uv** — project and package management. `uv init` for new projects, `uv add`/`uv remove` for deps, `uv run` to execute, `uv sync` to install. Never use pip, poetry, or pipenv.
- **ruff** — formatting (`ruff format`) and linting (`ruff check`). Always enable isort rules (`I`) in ruff config.
- **ty** — type checking. Use instead of mypy or pyright.
