# CLAUDE.md Personal Development Preferences

# IMPORTANT and CRITICAL

* The current month is March 2026
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

# Anti-Hallucination and Code Quality

Sources: github.com/obra/dotfiles, github.com/trailofbits/claude-code-config

* NEVER invent technical details. If you don't know an environment variable name, API endpoint, CLI flag, or configuration option -- stop and research it or explicitly state you don't know. Do not fabricate.
* NEVER document, validate, or reference features that aren't implemented. Don't add config keys, CLI flags, or API parameters that don't exist in the current codebase.
* NEVER write tests that assert mocked behavior. If a test mocks a function and then asserts the mock returns what the mock was configured to return, the test is worthless. Flag such tests.
* NEVER implement mocks in end-to-end tests. E2E tests use real data and real APIs.
* NEVER throw away or rewrite existing implementations without explicit permission. If an implementation seems wrong, ask before replacing it.
* NEVER use `git add -A` or `git add .` without running `git status` first. These can commit test artifacts, temp files, or secrets.
* Match the style and formatting of surrounding code, even if it differs from standard style guides. Consistency within a file trumps external standards. Do not change whitespace that doesn't affect execution.
* Use plain, factual language in PRs and commits. A bug fix is a bug fix, not a "critical stability improvement." Avoid inflated words: critical, crucial, essential, significant, comprehensive, robust, elegant.
* Complete all workflow steps (review, test, verify) even for small changes. Never skip process steps because a task seems trivial.
* Don't abandon a working repetitive approach mid-task. Tedious, systematic work is often the correct solution.
* When a new implementation replaces an old one, remove the old one entirely. No backward-compatible shims, dual config formats, or migration paths unless explicitly requested.

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

## ask

Use `ask` to query external AI models. Use it for exploratory questions,
brainstorming, getting a second opinion, or when you want idea diversity
from a different model. Run `ask --help` for full usage.

When to use `ask`:
- Brainstorming or exploring ideas (get a different model's perspective)
- Sanity-checking your approach with another model
- Getting alternative solutions or implementations
- Quick factual lookups where a second opinion helps

Examples:
```
# Get a second opinion from GPT-5.4
ask -Q -o "is there a simpler way to implement X"

# Brainstorm with GPT-5.4
ask -Q -o "what are the tradeoffs of approach A vs B"

# Include code files for context
ask -Q -o -f src/main.py "suggest improvements to this code"

# Pipe in context
git diff | ask -Q -o "review this diff"
```
