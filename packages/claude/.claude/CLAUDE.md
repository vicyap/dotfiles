# CLAUDE.md Personal Development Preferences

# IMPORTANT and CRITICAL

* The current month is February 2026
* When you have any uncertainty or doubt, ask me clarifying questions to make sure we are 100% aligned.
* When writing PR titles and descriptions, write them like git commit titles and descriptions. SKIP Test Plan.
* Always using at least 3 Explore agents when you explore a codebase.
* Avoid overuse of emojis, in any use cases.
* NEVER add "co-authored with Claude" when you write commit messages.
* NEVER add "🤖 Generated with Claude Code", including in PR descriptions.
* NEVER estimate implementation timelines or provide implementation effort estimates.
* NEVER delete production databases or data files without explicit user approval. Offer non-destructive alternatives first (ALTER TABLE, manual fixes, etc.).
* When editing GitHub PRs with `gh pr edit`, use `gh api` REST calls instead (e.g., `gh api repos/{owner}/{repo}/pulls/{number} -f title="..." -f body="..."`) to avoid "Projects (classic) is being deprecated" GraphQL errors.
* Proactively use Context7 (via `resolve-library-id` then `query-docs`) to look up library/framework documentation when writing or debugging code that uses external dependencies. Don't rely on training data for API details -- fetch current docs instead.
* Shell aliases `rm='rm -i'`, `cp='cp -i'`, and `mv='mv -i'` are set for user safety. These cause interactive prompts that hang Bash tool execution. When using these commands, pass `-f` to override (e.g., `rm -f`, `cp -f`, `mv -f`). Double-check targets before using `-f` -- the safety aliases exist for a reason.

# Git Worktrees

Worktrees live in `.worktrees/` inside the repo root:
```
repo-name/
├── .worktrees/         # Feature worktrees here
│   └── feat-name/
├── src/
└── .gitignore          # Must include .worktrees/
```

Commands:
- Create: `git worktree add .worktrees/<name> -b <name>`
- List: `git worktree list`
- Remove: `git worktree remove .worktrees/<name>`

Prefer naming using kebab-case, do not use "/" in names.

# Helpful Programs

## web

Use `web` to get markdown from websites. Useful alternative to Fetch for reading websites.

If Fetch ever returns a 403, retry with `web`.

Here is the help text:
```
web - portable web scraper for llms

Usage: web <url> [options]

Options:
  --help                     Show this help message
  --raw                      Output raw page instead of converting to markdown
  --truncate-after <number>  Truncate output after <number> characters and append a notice (default: 100000)
  --screenshot <filepath>    Take a screenshot of the page and save it to the given filepath
  --form <id>                The id of the form for inputs
  --input <name>             Specify the name attribute for a form input field
  --value <value>            Provide the value to fill for the last --input field
  --after-submit <url>       After form submission and navigation, load this URL before converting to markdown
  --js <code>                Execute JavaScript code on the page after it loads
  --profile <name>           Use or create named session profile (default: "default")

Phoenix LiveView Support:
This tool automatically detects Phoenix LiveView applications and properly handles:
- Connection waiting (.phx-connected)
- Form submissions with loading states
- State management between interactions

Examples:
  web https://example.com
  web https://example.com --screenshot page.png --truncate-after 5000
  web localhost:4000/login --form login_form --input email --value test@example.com --input password --value secret
```
