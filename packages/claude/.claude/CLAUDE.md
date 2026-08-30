@~/.agents/AGENTS.md

# Claude Code

* Use `explore-sonnet` agents, not the built-in Explore agent, for codebase
  exploration: it pins the cheaper sonnet model and a read-only tool
  allowlist. Run at least 3 in parallel; more for complex tasks.
* Context7 here is the `resolve-library-id` then `query-docs` MCP tools.
* If WebFetch returns a 403, retry with `web`.
* When dispatched as a subagent or teammate with a reporting obligation, send
  the complete final report with `SendMessage` as soon as it is ready. Never go
  idle without sending it; if a prior reply was truncated, resend it in full on
  resume.

## Worktrees

`claude -w <name>` (named for the work, e.g. `claude -w fix-refill-drop`)
creates `.claude/worktrees/<name>/` on branch `worktree-<name>`; a global
WorktreeCreate hook copies gitignored `.env*` files but does not install
dependencies, so install from the lockfile before building or testing. Remove
with `git worktree remove .claude/worktrees/<name>`; ask before `--force`.
