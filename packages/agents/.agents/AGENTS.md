# Personal Agent Instructions

These instructions apply to all AI coding agents.

## Per-Project Convention

```
project/
├── AGENTS.md                  # Shared instructions (all agents read this)
├── CLAUDE.md                  # @AGENTS.md + Claude Code specifics
├── .agents/
│   └── skills/                # Universal agent skills
├── .claude/
│   ├── skills -> ../.agents/skills  # Symlink to universal skills
│   └── rules/                 # Claude Code path-scoped rules
└── subdirectory/
    ├── AGENTS.md              # Subdirectory-scoped shared instructions
    └── CLAUDE.md              # @AGENTS.md + Claude Code specifics
```

AGENTS.md is the single source of truth at each level. Agent-specific files import it and add only agent-specific overrides.

Every CLAUDE.md starts with `@AGENTS.md`:

```markdown
@AGENTS.md

# Claude Code

Agent-specific instructions here (or omit this section if none).
```

Subdirectories can have their own AGENTS.md + CLAUDE.md pairs for progressive disclosure.

---

## General

* When uncertain, ask clarifying questions.
* Avoid overuse of emojis.
* NEVER estimate implementation timelines.
* NEVER delete production databases or data files without explicit approval. Offer non-destructive alternatives first.

## PRs and Commits

* Write PR titles and descriptions like git commit messages. Skip test plans.
* For `usetemi/` repos, PRs are always squash-merged. Write the PR title as the commit subject and the description as the commit body -- the result should read as a single well-formed commit message.
* Don't include meta-commentary (test counts, CI status, tool versions) in commit messages or PR descriptions.
* NEVER add AI co-authorship attribution to commit messages.
* NEVER add AI-generated badges or watermarks to PR descriptions.
* Use plain, factual language. Avoid inflated words: critical, crucial, essential, significant, comprehensive, robust, elegant.

## Anti-Hallucination

Sources: github.com/obra/dotfiles, github.com/trailofbits/claude-code-config

* NEVER invent technical details. If you don't know something -- research it or say so. Do not fabricate.
* NEVER document, validate, or reference features that aren't implemented.

## Code Quality

* NEVER throw away or rewrite existing implementations without explicit permission.
* NEVER use `git add -A` or `git add .` without running `git status` first.
* Match the style of surrounding code. Consistency within a file trumps external standards.
* Complete all workflow steps (review, test, verify) even for small changes.
* Don't abandon a working repetitive approach mid-task.
* When replacing an implementation, remove the old one entirely. No backward-compatible shims unless requested.

## Testing

* NEVER write tests that assert mocked behavior. Tests that assert a mock returns what it was configured to return are worthless.
* NEVER implement mocks in end-to-end tests. E2E tests use real data and real APIs.

## Code Style

* Prefer functional composition over object-oriented inheritance.
* Use descriptive variable names. No single-letter names except counters/iterators.
* No abbreviated variable names unless widely recognized (e.g., `id`, `url`, `html`).
* No deprecation comments when removing code.
* Simplicity over backwards compatibility: use modern language features, remove deprecated code paths.
* Rule of Three: don't abstract until you have 3 use cases.

## Tools

### Context7

Proactively look up library/framework documentation when working with external dependencies. Don't rely on training data for API details.

### ask

Query external AI models for second opinions or brainstorming. Run `ask --help` for usage.

```bash
ask -Q -o "is there a simpler way to implement X"
ask -Q -o -f src/main.py "suggest improvements"
git diff | ask -Q -o "review this diff"
```

### web

Get markdown from websites. Run `web --help` for usage.

```bash
web https://example.com
web https://example.com --truncate-after 5000
```
