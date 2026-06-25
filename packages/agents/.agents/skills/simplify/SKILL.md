---
name: simplify
description: >-
  Review changed code for simplification opportunities, then make scoped fixes.
  Use when the user invokes simplify, says /simplify, asks to simplify a diff,
  asks to reduce code complexity, asks for a cleanup pass after implementation,
  or wants changed code reviewed for reuse, quality, and efficiency. Defaults to
  changed files from git diff and uses three reviewer passes: code reuse, code
  quality, and efficiency.
# Edits files directly (see Operating Contract), so require explicit invocation
# rather than letting the model auto-trigger on keywords.
disable-model-invocation: true
---

# Simplify

Run a focused cleanup pass over changed code. The goal is not broad refactoring;
it is to remove avoidable complexity introduced by the current diff.

This is a Codex port of Claude Code's built-in `/simplify` workflow:

1. Identify changed code.
2. Review it through three lenses: reuse, quality, and efficiency.
3. Apply direct, scoped fixes for real issues and skip false positives.

## Operating Contract

Default to editing directly. The user invoked this skill because they want the
changed code simplified, not just reviewed.

Keep scope tight:

- Review the current git diff by default.
- Change only files already touched by the diff unless a small supporting edit
  is clearly required to use an existing helper or remove duplication.
- Do not expand product scope, alter behavior intentionally, or start unrelated
  cleanup.
- Preserve user changes and unrelated dirty work.
- Prefer deleting code, using existing helpers, and simplifying control flow over
  adding abstractions.

If the request includes extra focus text, treat it as guidance, not a new scope
boundary unless the user says so explicitly.

## Phase 1: Identify Changes

Start by establishing the review target:

1. Run `git status --short`.
2. Prefer `git diff HEAD -- <paths>` semantics for changed files so staged and
   unstaged changes are both included.
3. If there is no git diff, inspect recently modified files only as a fallback
   and say that fallback is being used.
4. Read the relevant local instructions before touching files:
   - nearest `AGENTS.md`
   - language or framework rules named by those instructions
   - any touched-directory `AGENTS.md`

Before editing, understand the surrounding implementation well enough to avoid
rewriting a local pattern into a personal preference.

## Phase 2: Three Reviewer Passes

Use three independent reviewer passes. When the harness allows subagents for this
invocation, run these as separate parallel reviewers and have them return concise
findings with file/line evidence. When subagents are unavailable or tool policy
does not permit them, run the same three passes locally and keep the findings
separate before integrating them.

### Code Reuse

Look for new code that duplicates existing helpers, utilities, components,
repository methods, service functions, constants, schemas, types, or test
fixtures.

Check for:

- newly added helpers that already exist elsewhere
- hand-rolled parsing, formatting, validation, retry, date, ID, or URL logic
- copy-pasted UI, action, service, repository, or test setup logic
- local constants where shared constants or typed unions already exist
- new dependency or SDK usage that bypasses existing singleton/service patterns

Return only reuse findings that point to a concrete existing replacement.

### Code Quality

Look for complexity that makes the changed code harder to understand or maintain.

Check for:

- redundant state or cached derived values
- parameter sprawl and boolean flag proliferation
- copy-paste with minor variation
- leaky abstractions or pass-through wrappers
- stringly typed code where local constants, unions, or schemas exist
- unnecessary JSX nesting or wrapper elements
- conditionals nested three or more levels deep
- comments that narrate what code does, mention task history, or compensate for
  unclear names
- abstractions introduced before three real use cases

Prefer small rewrites that make the code read more directly.

### Efficiency

Look for avoidable work introduced by the diff.

Check for:

- redundant computation or repeated parsing
- N+1 data access or loops that should batch
- missed concurrency for independent async operations
- hot-path bloat
- polling or interval code that performs recurring no-op updates
- time-of-check/time-of-use existence checks
- memory leaks, unbounded maps/arrays/caches, or retained subscriptions
- overly broad reads, selects, payloads, or dependency imports

Only fix efficiency issues with a clear local payoff. Do not turn simple code
into speculative performance architecture.

## Phase 3: Integrate And Fix

Aggregate the three reviewer outputs before editing:

1. Deduplicate overlapping findings.
2. Reject false positives silently unless the reason matters to the final note.
3. Prioritize behavior-preserving simplifications with low blast radius.
4. Edit with the smallest coherent patch.
5. Remove dead code made obsolete by the simplification.
6. Run targeted checks appropriate to the changed files.

When a potential simplification would require a broad redesign, record it as an
optional follow-up instead of implementing it.

## Verification

Choose verification proportional to the edits:

- TypeScript/React: run typecheck and relevant tests when available; run lint if
  the project uses it for touched files.
- Backend/service code: run focused unit or integration tests covering touched
  behavior.
- Frontend behavior changes: run relevant browser or component checks if the
  edit affects visible behavior.
- Docs-only cleanup: no test command is required.

If a check cannot be run, say why.

## Final Response

Keep the final response short:

- summarize what was simplified
- name the checks run
- call out skipped risky findings or remaining follow-ups only when useful

Do not include the full reviewer transcript unless the user asks for it.
