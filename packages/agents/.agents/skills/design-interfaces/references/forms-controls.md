# Forms And Controls

Ask only for information needed now. Group fields by user concept, order them by
the task, preserve labels, choose native controls where possible, and set input
types and autocomplete tokens correctly. Explain why sensitive or surprising
data is required. Preserve valid input through errors and validate at the point
where the user can act on the result.

## Patterns

### Forgiving Format
Accept multiple reasonable representations and normalize them after entry. Show
the interpreted value when ambiguity matters and never silently reinterpret a
consequential input.

### Structured Format
Constrain input to a known structure when each segment has independent meaning or
validation. Allow paste, deletion, selection, and keyboard navigation naturally;
avoid fragmented fields that fight standard editing.

### Fill-In-The-Blanks
Embed inputs in a short natural-language sentence when the surrounding words make
the request easier to understand. Keep reading and focus order logical and avoid
this pattern for long, dynamic, or localization-sensitive forms.

### Input Hints
Provide concise format or purpose guidance next to a field before errors occur.
Keep it visible while editing and do not repeat the label or rely on placeholder
text.

### Input Prompt
Offer an example or lightweight cue inside an empty control only as supplemental
help. Remove it without becoming content, and retain a persistent external label.

### Password Strength Meter
Explain password requirements and update satisfied rules during entry. Do not
claim security from an opaque score, block password managers, prevent paste, or
expose the secret.

### Autocompletion
Suggest likely valid values as users type when the candidate set or history can
reduce effort. Distinguish suggestions from committed values, support keyboard
selection, announce updates, and allow novel input when the domain permits it.

### Drop-Down Chooser
Provide a bounded set of recognizable choices in a compact control. Use radio
buttons when comparison matters, search when the set is large, and avoid custom
menus that weaken native semantics. For large sets such as currencies, countries,
or categories, use a relevant shortlist plus search instead of a long native
select.

### List Builder
Let users construct a selected set from available items. Make membership and
ordering visible, prevent duplicates, support search for large sources, and
provide keyboard alternatives to drag-and-drop.

### Good Defaults And Smart Prefills
Populate likely, safe values from known context to reduce work. Show the value,
its scope, and its source when surprising; never preselect consent, purchases, or
irreversible choices.

### Error Messages
Place a plain-language explanation at the problem and summarize when several
errors exist. State what happened, why when useful, and exactly how to recover;
preserve input and move focus deliberately without announcing errors repeatedly.

## Review Checklist

- Is every field necessary, labeled, grouped, and ordered by user task?
- Do defaults reduce work without creating hidden consent or consequence?
- Can users paste, autofill, use password managers, and complete by keyboard?
- Are validation timing, error association, and recovery clear?
- Are submission, loading, duplicate prevention, success, and retry states covered?
