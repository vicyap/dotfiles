# Git Worktrees

Claude Code has built-in worktree support via `claude -w`. A global WorktreeCreate
hook creates the worktree and copies gitignored `.env*` files automatically.

**Dependencies are not pre-installed.** After entering a worktree, install
dependencies before running builds, dev servers, or tests. Detect lockfiles and
run the matching package manager (e.g., `npm install` for `package-lock.json`).

## Creating a Worktree

Use `claude -w <name>` from the CLI. This:

1. Creates `.claude/worktrees/<name>/` with branch `worktree-<name>`
2. Copies all gitignored `.env*` files from the main repo to matching paths

To include a Linear issue ID, put it in the name:

```bash
claude -w USE-123-fix-bug
```

This creates branch `worktree-USE-123-fix-bug`, which Linear auto-links.

## Listing Worktrees

```bash
git worktree list
```

## Removing a Worktree

```bash
git worktree remove .claude/worktrees/<name>
git worktree prune
```

If the worktree has uncommitted changes, `git worktree remove` will fail. Inform
the user and ask before using `--force`.
