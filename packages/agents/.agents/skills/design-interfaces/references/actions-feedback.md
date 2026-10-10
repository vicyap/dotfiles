# Actions, Commands, Feedback, And Recovery

Match controls to input method and consequence. Buttons perform actions; links
navigate. Menus conserve space for secondary commands; toolbars expose frequent
ones. Support predictable keyboard order and shortcuts, and provide non-drag
alternatives. Affordances and direct manipulation must remain perceivable without
hover or prior training.

## Patterns

### Button Groups
Present related peer actions or modes as a visually coherent set. Distinguish
selection from execution, keep labels clear, and separate destructive actions.

### Hover Or Pop-Up Tools
Reveal contextual secondary tools near an object to reduce clutter. Keep required
actions available through focus, touch, or a persistent menu; prevent accidental
dismissal during pointer travel.

### Action Panel
Collect commands for the current object or context in a stable visible region.
Prioritize frequent actions, update scope clearly, and avoid duplicating global
navigation.

### Prominent Done Button Or Assumed Next Step
Make the natural completion action easy to find when a task has a clear end.
Enable it only when requirements are satisfied, explain blocking validation, and
avoid competing primary actions.

### Smart Menu Items
Adapt command labels or availability to current context while keeping placement
and meaning predictable. Prefer explicit state over commands that silently change
behavior.

### Preview
Show the likely result before a consequential, expensive, or hard-to-visualize
action. Use representative data, expose uncertainty, and let users revise inputs
without losing context.

### Spinners And Loading Indicators
Acknowledge an action immediately and distinguish indeterminate activity from
measurable progress. Prevent duplicate submission, preserve context, and offer a
way out when waiting can fail or continue too long.

### Cancelability
Allow an in-progress operation or task to stop when continuing has meaningful
cost. Explain what was already applied and preserve safe intermediate work.

### Multilevel Undo
Support reversing a sequence of edits in understandable order. Keep undo and redo
scope visible, avoid mixing unrelated histories, and persist history only when
users reasonably expect it.

### Command History
Record meaningful past operations for inspection, reuse, or recovery. Include
parameters and outcomes, protect sensitive data, and distinguish history from an
undo stack.

### Macros
Let experts package a repeated sequence into a reusable command when repetition
is stable and costly. Make scope, inputs, permissions, preview, and failure
handling explicit.

## Review Checklist

- Is every action's target, scope, state, and consequence clear?
- Are primary, secondary, and destructive commands visually distinct?
- Does feedback arrive immediately and remain until understood when necessary?
- Can users cancel, undo, retry, or recover in proportion to consequence?
- Are commands available to keyboard, touch, pointer, and assistive technology?
