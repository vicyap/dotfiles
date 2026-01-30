---
description: Commit staged changes
model: opus
---

# Commit Changes

You are tasked with creating git commits for only the staged changes.

## Important

- **NEVER add co-author information or Claude attribution**
- Commits should be authored solely by the user
- Do not include any "Generated with Claude" messages
- Do not add "Co-Authored-By" lines
- Write commit messages as if the user wrote them

## Commit Message Format

**Required format:** `<emoji> <type>(scope): <description>`

```
<emoji> <type>(scope): <short summary>
  │       │      │             │
  │       │      │             └─⫸ Summary in present tense. Not capitalized. No period at the end.
  │       │      │
  │       │      └─⫸ Commit Scope: api|ui|auth|db|config|etc
  │       │
  │       └─⫸ Commit Type: feat|fix|docs|style|refactor|perf|test|chore
  │
  └─⫸ Gitmoji: Visual indicator of commit type (REQUIRED)

[optional body]

[optional footer(s)]
```

### Character Limits

- **Subject line**: 50 characters (50 max)
- **Body**: Wrap at 72 characters per line
- Use imperative mood: "add feature" not "added feature"

## Gitmoji + Type Reference

Use the appropriate emoji and type combination for your commit:

| Emoji | Code                 | Type     | When to Use                             |
| ----- | -------------------- | -------- | --------------------------------------- |
| ✨    | `:sparkles:`         | feat     | New feature for users                   |
| 🐛    | `:bug:`              | fix      | Bug fix for users                       |
| 📝    | `:memo:`             | docs     | Documentation only changes              |
| 🎨    | `:art:`              | style    | Code structure/format (not CSS)         |
| ♻️    | `:recycle:`          | refactor | Code change (no bug fix or new feature) |
| ⚡    | `:zap:`              | perf     | Performance improvement                 |
| ✅    | `:white_check_mark:` | test     | Adding or updating tests                |
| 🔧    | `:wrench:`           | chore    | Build process, dependencies, config     |
| 💚    | `:green_heart:`      | ci       | CI/CD pipeline fixes                    |
| 🔒    | `:lock:`             | security | Security fixes                          |
| 🔥    | `:fire:`             | remove   | Removing code or files                  |
| 🚧    | `:construction:`     | wip      | Work in progress (avoid in main/shared) |
| ⬆️    | `:arrow_up:`         | deps     | Upgrade dependencies                    |
| ⬇️    | `:arrow_down:`       | deps     | Downgrade dependencies                  |
| 🚨    | `:rotating_light:`   | lint     | Fix linter warnings                     |

## Using Scopes

Scopes provide context about what part of the codebase changed:

**Common scopes:**

- `auth` - Authentication/authorization
- `api` - API routes or endpoints
- `ui` - User interface components
- `db` - Database schema or queries
- `config` - Configuration files
- Component names: `dashboard`, `profile`, `settings`
- Feature areas: `billing`, `notifications`, `analytics`

**Examples:**

- `✨ feat(auth): add OAuth login support`
- `🐛 fix(api): resolve timeout on user endpoint`
- `♻️ refactor(dashboard): extract stats widget component`
- `🔧 chore(deps): upgrade next to v15.1.0`

Scope is optional but recommended for clarity.

## Multi-line Commits

For complex changes, use body and footer to provide context:

```
✨ feat(api): add user authentication endpoint

Implement OAuth 2.0 flow with JWT tokens. The endpoint validates
credentials against Auth0 and returns access and refresh tokens.

This provides the foundation for the upcoming user dashboard feature
and replaces the legacy session-based authentication.
```

**Body guidelines:**

- Explain WHY, not WHAT (code shows what)
- Describe motivation and contrast with previous behavior
- Wrap at 72 characters
- Separate from subject with blank line

## Breaking Changes

For changes that break backward compatibility, use the `BREAKING CHANGE:` footer:

```
✨ feat(api): change user endpoint response format

Update the /api/users endpoint to return camelCase field names
instead of snake_case for consistency with the rest of the API.

BREAKING CHANGE: User API responses now use camelCase. Clients must
update field access from user.first_name to user.firstName and
user.last_name to user.lastName.
```

**When to use:**

- API changes that affect clients
- Removed features or endpoints
- Changed function signatures in public APIs
- Database migrations requiring manual intervention
- Configuration format changes

## Examples

**Simple feature:**

```
✨ feat(dashboard): add user stats widget
```

**Bug fix with context:**

```
🐛 fix(api): prevent timeout on large file uploads

Increase the request timeout from 30s to 5m for file upload endpoints.
The previous timeout was too aggressive for users with slow connections.
```

**Refactoring:**

```
♻️ refactor(auth): extract token validation logic

Move JWT validation into a shared utility to reduce duplication across
API routes and improve testability.
```

**Documentation:**

```
📝 docs(readme): update installation instructions
```

**Dependency update:**

```
⬆️ chore(deps): upgrade prisma to v6.2.0

Includes performance improvements for PostgreSQL queries and fixes
for TypeScript 5.8 compatibility.
```

**Breaking change:**

```
✨ feat(billing): migrate to Stripe Checkout v3

Replace custom payment form with Stripe's hosted checkout for improved
security and PCI compliance. This simplifies our payment flow and
reduces maintenance burden.

BREAKING CHANGE: The /api/payment/charge endpoint has been removed.
Use /api/payment/create-session instead, which redirects to Stripe
Checkout and handles the payment flow.
```

## Process

1. **Think about what changed:**
   - Run `git diff --staged` to see currently staged changes
   - Consider whether changes should be one commit or multiple logical commits

2. **Plan your commit(s):**
   - Identify which files belong together
   - Select appropriate emoji + type for each commit
   - Determine the scope (component, feature area, or subsystem)
   - Draft clear, descriptive commit messages
   - Use imperative mood in commit messages
   - Focus on WHY the changes were made, not just WHAT
   - Decide if body/footer are needed to explain context

3. **Execute the commit(s):**
   - Inform the user what files and commit messages will be used
   - Use `git add` with specific files (never use `-A` or `.`)
   - Create commits with your planned messages
   - Show the result with `git log --oneline -n [number]`

## Remember

- Only commit staged changes
- You have the full context of what was done in this session
- Group related changes together
- Keep commits focused and atomic when possible
- Each commit should represent one logical change
- The user trusts your judgment - they asked you to commit
- **NEVER add co-author information or Claude attribution**
