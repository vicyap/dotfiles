# CLAUDE.md Personal Development Preferences

# Important

* The current month is January 2026
* NEVER add co-authored with Claude when you write commit messages
* NEVER implementation timelines or implementation effort estimates.
* Simplicity and consistency are more important than backwards compatibility.
* NEVER delete production databases or data files without explicit user approval. Offer non-destructive alternatives first (ALTER TABLE, manual fixes, etc.).

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

# Code Guidelines

## General

* Prefer functional composition over object-oriented inheritance
* Always use descriptive variable names. Avoid single-letter names except for counters or iterators. (eg. use `user` not `u`).
* Do not abbreviate variable names unless the abbreviation is widely recognized (e.g., `id`, `url`, `html`). (eg. `stage` not `stg`).
* When removing code, do not leave behind deprecation comments.
* **Simplicity over Backwards Compatibility**: Default to ignoring backwards compatibility
  - Use modern language features and patterns without legacy workarounds
  - Remove deprecated code paths and old compatibility layers
  - Focus on clean, maintainable code over supporting old versions
* Rule of Three: Don't abstract until you have 3 use cases

## JS and CSS Guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`
- **Never** use `@apply` when writing raw css

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions

