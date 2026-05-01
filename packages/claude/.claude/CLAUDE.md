@~/.agents/AGENTS.md

# Claude Code

* ALWAYS use explore-sonnet agents instead of the default Explore agents.
* Always use at least 3 explore-sonnet agents when you explore a codebase.
* Proactively use Context7 via `resolve-library-id` then `query-docs` MCP tools.
* When editing GitHub PRs with `gh pr edit`, use `gh api` REST calls instead (e.g., `gh api repos/{owner}/{repo}/pulls/{number} -f title="..." -f body="..."`) to avoid "Projects (classic) is being deprecated" GraphQL errors.
* Shell aliases `rm='rm -i'`, `cp='cp -i'`, and `mv='mv -i'` are set for user safety. These cause interactive prompts that hang Bash tool execution. When using these commands, pass `-f` to override (e.g., `rm -f`, `cp -f`, `mv -f`). Double-check targets before using `-f`.
* If Fetch returns a 403, retry with `web`.
