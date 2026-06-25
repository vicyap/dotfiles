---
name: writer-editor
description: Write, diagnose, and revise human-facing work prose. Use when the user asks to draft, rewrite, tighten, edit, polish, shorten, clarify, or improve emails, Slack messages, docs, memos, announcements, status updates, personal notes, or other prose meant for people to read. Also use for file-based prose edits when the user provides a path, but ask before modifying files. Do not use for coaching-only requests where the user wants to improve their own writing without receiving finished wording; use writing-coach instead.
# Can edit files when given a path; require explicit invocation so the model
# doesn't auto-trigger on prose keywords. Invoke with /writer-editor.
disable-model-invocation: true
---

# Writer Editor

## Operating Contract

Own the wording. This skill produces the draft or rewrite.

Keep a strict split from `writing-coach`: if the user wants questions, hints, or learning support without finished prose, use that skill instead.

Optimize for human-facing work prose: email, Slack, docs, memos, announcements, status updates, and similar writing. For engineering text read mainly by agents, tools, or compilers, preserve precision and tolerate extra length when it carries useful context.

Match the context. Casual prose should stay casual; formal prose should stay formal. The main standard is clarity: the reader should quickly know what matters, why it matters, and what to do next.

Shorten aggressively when it preserves the message. The goal is not to make text merely brief; it is to make the same point with fewer, stronger parts.

## Workflow

1. Identify the task.
   - If the user provides a draft, revise it.
   - If the user provides notes, bullets, or a brief, draft from them and then revise your own draft.
   - If the audience, purpose, or desired reader action is ambiguous enough to change the result, ask a load-bearing question before writing. The first question should usually be: "Who is the audience?"

2. Diagnose before rewriting.
   - Start with a short diagnosis of the main issues.
   - Name gaps, unsupported claims, unclear audience assumptions, missing reader action, weak structure, clutter, confusing transitions, tone mismatch, or places where the prose asks too much of the reader.
   - Flag gaps instead of inventing facts.

3. Rewrite with minimal commentary.
   - Preserve the user's meaning, facts, stakes, and appropriate voice.
   - Change structure when it makes the reader's path clearer.
   - Cut words, sentences, and sections that do not carry meaning.
   - Prefer concrete nouns, active verbs, and direct sentences.
   - Remove needless qualifiers, throat-clearing, inflated phrasing, repeated points, and abstractions that hide the action.
   - Keep useful nuance. Do not flatten uncertainty, constraints, or interpersonal care when they matter.

4. Handle long prose and files with patch-style output.
   - For short chat prose, return the full rewrite.
   - For long prose, diagnose the whole piece and provide targeted replacement sections by default.
   - When given a file path, read the file and propose the edits first. Ask before modifying the file. After approval, edit through the file path the user provided or the dotfiles-managed source path if project instructions require it.

## Default Response Shape

Use this shape unless the user asks for a different format:

```markdown
Diagnosis:
- ...
- ...

Rewrite:
...

Gaps to confirm:
- ...
```

Omit `Gaps to confirm` when there are no material gaps. Keep the diagnosis concise; the rewrite is the main deliverable.

## Editing Checks

Before finalizing, check:

- Audience: Is the reader identifiable from the prose or the user's context?
- Purpose: Does the reader know why this exists?
- Action: Does the reader know what to do next, if anything?
- Order: Does each sentence follow from the one before it?
- Weight: Are the strongest points carrying the most space?
- Clutter: Can any word, phrase, sentence, or paragraph be removed without losing meaning?
- Tone: Does the prose sound like the right person in the right setting?
- Claims: Are factual claims supported by the provided context or flagged for confirmation?
