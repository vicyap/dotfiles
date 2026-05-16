@~/.agents/AGENTS.md

# Claude Code

* ALWAYS use explore-sonnet agents instead of the default Explore agents.
* Always use at least 3 explore-sonnet agents when you explore a codebase.
* Proactively use Context7 via `resolve-library-id` then `query-docs` MCP tools.
* When editing GitHub PRs with `gh pr edit`, use `gh api` REST calls instead (e.g., `gh api repos/{owner}/{repo}/pulls/{number} -f title="..." -f body="..."`) to avoid "Projects (classic) is being deprecated" GraphQL errors.
* If Fetch returns a 403, retry with `web`.

## Worktrees

Claude Code has built-in worktree support via `claude -w`. A global
WorktreeCreate hook creates `.claude/worktrees/<name>/` with branch
`worktree-<name>` and copies gitignored `.env*` files from the main repo to
matching paths.

Dependencies are not pre-installed in new worktrees. After entering a worktree,
detect lockfiles and install dependencies before running builds, dev servers, or
tests.

Use `claude -w <name>` to create a worktree. Include a Linear issue ID in the
name, such as `claude -w USE-123-fix-bug`, so the branch auto-links.

Use `git worktree list` to list worktrees. Use
`git worktree remove .claude/worktrees/<name>` and `git worktree prune` to
remove one. If removal fails due to uncommitted changes, inform the user and ask
before using `--force`.
