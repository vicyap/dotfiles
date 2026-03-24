# Git Worktrees

When creating, listing, or removing git worktrees, follow these procedures exactly.

## Directory Layout

Worktrees live in `.worktrees/` inside the repo root:
```
~/code/{owner}/{repo}/
├── .worktrees/
│   └── branch-name/     # Each worktree
├── .env                  # Shared env (symlinked into worktrees)
├── .env.local            # Optional, also symlinked if present
├── src/
└── .gitignore            # Must include .worktrees/
```

## Creating a Worktree

Run these steps in order:

### 1. Ensure `.worktrees/` is gitignored

Check `.gitignore` for `.worktrees/`. If missing, add it.

### 2. Create the worktree

```bash
git worktree add .worktrees/<name> -b <branch-name>
```

The caller decides both `<name>` (directory) and `<branch-name>`. Do not enforce naming conventions here.

### 3. Symlink env files

From the repo root:

```bash
ln -sf ../../.env .worktrees/<name>/.env
```

If `.env.local` exists at the repo root:
```bash
ln -sf ../../.env.local .worktrees/<name>/.env.local
```

### 4. Auto-populate `.env` from `~/.secrets` (if `.env` is missing)

If the repo root has no `.env`:

1. Look for `.env.example` or `.env.template` in the repo root.
2. If a template exists, read its variable names and match them against `~/.secrets` (`export VAR='value'` format). Write matches to `.env` in `VAR=value` format (no `export`, no quotes unless the value contains spaces).
3. If no template exists, inform the user that `.env` is missing and suggest they create one or copy from `~/.secrets` manually.
4. Then symlink as in step 3.

### 5. Install dependencies

Auto-detect the package manager from lockfiles in the **worktree** directory and install:

| Lockfile | Command |
|----------|---------|
| `package-lock.json` | `npm install` |
| `yarn.lock` | `yarn install` |
| `pnpm-lock.yaml` | `pnpm install` |
| `bun.lockb` or `bun.lock` | `bun install` |
| `uv.lock` | `uv sync` |
| `Cargo.lock` | `cargo build` |
| `go.sum` | `go mod download` |
| `Gemfile.lock` | `bundle install` |
| `composer.lock` | `composer install` |

If the project is a monorepo with multiple lockfiles in subdirectories, install in each subdirectory that has one.

### 6. Additional bootstrapping

- If the project uses git hooks (e.g., Husky), run the prepare script: `npm run prepare` (or equivalent).
- If `node_modules/.cache` or similar build caches exist at the repo root, they do not need to be copied -- fresh installs create their own.

## Listing Worktrees

```bash
git worktree list
```

## Removing a Worktree

```bash
git worktree remove .worktrees/<name>
```

If the worktree has uncommitted changes, `git worktree remove` will fail. In that case, inform the user and ask before using `--force`.

After removal, prune stale references:
```bash
git worktree prune
```
