@~/.agents/AGENTS.md

# Claude Code

* ALWAYS use explore-sonnet agents instead of the default Explore agents.
* Always use at least 3 explore-sonnet agents when you explore a codebase.
* Proactively use Context7 via `resolve-library-id` then `query-docs` MCP tools.
* When editing GitHub PRs with `gh pr edit`, use `gh api` REST calls instead (e.g., `gh api repos/{owner}/{repo}/pulls/{number} -f title="..." -f body="..."`) to avoid "Projects (classic) is being deprecated" GraphQL errors.
* If Fetch returns a 403, retry with `web`.
