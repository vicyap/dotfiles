---
name: ask-clarifying-questions
description: Conduct a clarification interview (up to 4 questions per round via the AskUserQuestion tool, multiple rounds as needed) to align with the user before writing any code. Use when the user invokes /ask-clarifying-questions explicitly, or when they ask to build / design / refactor something with a brief vague enough that meaningfully different implementations would all "satisfy" it. The interview output is shared understanding in the current session — no file artifact.
---

# Ask Clarifying Questions

Drive a structured interview to surface load-bearing assumptions before any code is written. Up to 4 questions per round via the `AskUserQuestion` tool, multiple rounds as needed. The "output" is shared understanding in the current session — no file artifact is produced.

## When to Use

- The user invokes `/ask-clarifying-questions` explicitly.
- The user asks to build a feature, refactor, or design something and the brief is short or leaves room for meaningfully different implementations.
- Skip when: the request is mechanical (typo fix, obvious rename, a one-line bug fix the user has already diagnosed). Cheap requests don't earn an interview — clarification has its own cost.

## Process

### 1. Anchor

Restate in one sentence what you understand the user wants. This anchors the interview and gives the user a chance to redirect cheaply.

### 2. Ask up to 4 questions per round, ranked by load-bearing-ness

**Always use the `AskUserQuestion` tool** — the user prefers its clickable interface. Send up to 4 questions in a single call. Pick the 4 questions whose answers would most change the implementation — those whose two plausible answers lead to the most different code. Skip anything you can predict with high confidence.

Multiple-choice when there are clear discrete options; for open-ended cases, give a single best-guess option + let the user use "Other" for free text. Fall back to plain prose alongside the `AskUserQuestion` call only when the answer truly cannot be framed as a short choice (e.g., the user needs to paste a code snippet or write a paragraph).

### 3. Predict before you ask

For each question in the batch, write your predicted answer in your reasoning before sending. After receiving answers, note your hit rate. This is your calibration signal — vibes-based, not precise.

### 4. Infer the user's tradeoffs as you go (do not ask)

Build a mental model of the user's implicit tradeoff posture from their answers. Common axes: simplicity vs flexibility, short-term vs long-term, prototype vs production-hardened, vendor lock-in tolerance, performance vs readability, build vs buy. Adjust subsequent rounds to match what you've inferred.

Do **not** ask explicit "do you prefer X or Y" tradeoff questions. Infer it. Restate inferred tradeoffs only when surfacing one would let the user correct a wrong inference.

### 5. After each round, decide: another round or stop?

If your prediction hit-rate is around 95% AND you judge remaining ambiguity is not load-bearing, stop. Otherwise run another round, focused on whatever the previous round didn't resolve. Cap at 5 rounds — if you're still not aligned after that, surface it to the user rather than looping indefinitely.

### 6. Confirm and proceed

When you stop, summarize in 1–3 sentences what you're now aligned on, including any inferred tradeoffs the user should be able to correct (e.g., "Treating this as a prototype — prioritizing simplicity over flexibility"). Ask "Ready to proceed?" — then continue with whatever the next step is.

## Constraints

- **Don't write code or modify project files during the interview.** The interview is read-only and conversational.
- **Up to 4 questions per round.**
- **Always use the `AskUserQuestion` tool.** Plain prose only when the answer can't be framed as a short choice.
- **Cap rounds at 5.** If still not aligned, surface it to the user rather than looping.
- **Don't ask questions whose answers are already in the user's brief.**
- **Don't dump pre-written assumptions as questions.** A question is something whose answer could change the implementation.
- **Don't ask explicit tradeoff questions.** Infer the user's tradeoff posture from their answers.
