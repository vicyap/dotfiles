---
name: design-interfaces
description: >-
  Design, implement, or review screen-based interfaces using interaction-design
  patterns grounded in user goals, information architecture, navigation, layout,
  actions, feedback, forms, lists, data visualization, responsive behavior, and
  design systems. Use for new or existing web, mobile, or desktop UI when the
  task requires interaction reasoning, pattern selection, usability critique,
  workflow design, or concrete pattern-based fixes. Inspect both code and
  rendered evidence when available; compose with visual styling skills rather
  than replacing them.
---

# Design Interfaces

Design interfaces around what people are trying to accomplish. Make the
interaction model explicit, choose a small coherent set of patterns, explain the
choices briefly, and implement them when the user requested a change.

Read [Pattern Index](references/pattern-index.md) first. It routes each design
problem to the smallest relevant reference. Load only those references; do not
read the entire catalog for every task.

## Operating Contract

- Inspect the request, project instructions, existing UI conventions,
  components, routes, state model, and relevant tests before proposing a design.
- Inspect rendered evidence when available: screenshots, mockups, browser output,
  previews, or simulator output. Do not infer visual behavior from code alone
  when the rendered interface can be checked.
- Establish the audience, primary goal, key tasks, content shape, platform, input
  method, and important constraints. Ask only when missing information would
  materially change the interaction model.
- Separate interaction architecture from visual styling. Use this skill for
  structure and behavior; compose with an applicable visual-design skill such as
  `ui-design` when detailed styling is also requested.
- Treat the references as durable heuristics, not frozen platform law. Prefer
  current platform standards, accessibility requirements, and established
  project conventions when they conflict.
- Use the fewest patterns that solve the actual problem. Do not add screens,
  navigation, controls, customization, or flexibility without a user need.
- Do not invent product capabilities, data fields, collaboration models, or
  platform policies. Specify only behavior supported by the request or inspected
  artifacts. Mark a conditional behavior as conditional, and leave a genuine
  product decision unresolved when choosing it would expand scope.
- For review-only requests, remain read-only. For build or change requests,
  explain the chosen patterns briefly and then implement without a separate
  approval gate unless a scope-changing ambiguity remains.

## Workflow

### 1. Frame The Interaction

Identify:

- who is using the interface and their relevant skill or context
- the outcome they want, not merely the UI operation they perform
- the objects, collections, actions, and states in the task
- frequency, urgency, reversibility, and likely interruption
- screen size, input methods, accessibility needs, and environmental constraints

Map the shortest understandable path through the task. Prefer familiar language
and visible choices over internal system structure.

### 2. Choose The Structure

Use the pattern index to load references for the problem at hand. Decide in this
order:

1. content and task organization
2. navigation and screen relationships
3. layout and progressive disclosure
4. actions, input, feedback, and recovery
5. platform adaptation and visual hierarchy

State the selected patterns and why they fit in a compact design rationale. Name
important rejected patterns only when the tradeoff would otherwise be unclear.
Do not force a named pattern when a simpler conventional control is sufficient.

### 3. Implement Or Specify

When implementation is requested:

- reuse the project's components, tokens, routes, state conventions, and native
  platform controls
- preserve visible state across navigation and interruption where users expect it
- expose primary actions, make destructive actions distinguishable, and provide
  recovery proportional to consequence
- cover loading, empty, error, success, disabled, validation, focus, hover,
  pressed, and selected states that the interaction can reach
- keep pointer, keyboard, touch, and assistive-technology behavior equivalent
- adapt the same task model across breakpoints instead of shrinking a desktop
  arrangement mechanically

When only a design is requested, provide enough structure—screen relationships,
states, controls, and behavior—for another implementer to build without inventing
interaction decisions. When no implementation exists to inspect, keep assumptions
minimal and do not prescribe autosave, offline queues, live updates, deep links,
notifications, or collaborative behavior unless the task requires them.

### 4. Review

Lead with findings ordered by user impact. For each finding include:

- concrete evidence from the rendered UI or implementation
- the affected user goal or task
- the relevant principle or pattern
- the consequence
- the smallest concrete fix

Do not award points for the mere presence of named patterns. Report a problem
only when the current design obscures meaning, increases avoidable effort,
prevents access, causes errors, or weakens recovery.

### 5. Validate

Check the completed design against the original user goal and the applicable
reference checklists. Exercise representative viewport sizes and input methods.
Run project formatting, linting, type checks, and tests for touched code. Inspect
the rendered result again after implementation; code-level correctness does not
prove interaction quality.

## Reference Map

- User behavior and design framing: [Foundations](references/foundations.md)
- Content and application structure: [Information Architecture](references/information-architecture.md)
- Movement and orientation: [Navigation](references/navigation.md)
- Screen composition and disclosure: [Layout](references/layout.md)
- Hierarchy, aesthetics, and access: [Visual Style](references/visual-style.md)
- Small screens and touch: [Mobile and Responsive](references/mobile-responsive.md)
- Collections and result sets: [Lists and Collections](references/lists-collections.md)
- Commands, feedback, and recovery: [Actions and Feedback](references/actions-feedback.md)
- Dense or interactive information: [Complex Data](references/complex-data.md)
- Data entry and validation: [Forms and Controls](references/forms-controls.md)
- Reusable component languages: [Design Systems](references/design-systems.md)
- Connected and context-aware products: [Beyond the Screen](references/beyond-screen.md)

## Gotchas

- A dashboard is not the default home page. Use one only when people must monitor
  several changing measures or conditions together.
- A card is not a universal container. Use it for a coherent object or action,
  not as decoration around unrelated content.
- A carousel hides choices and weakens comparison. Avoid it when every item is
  important or users need to scan quickly.
- Infinite scrolling conflicts with position, return, comparison, and footer
  access. Prefer pagination or explicit loading when those needs matter.
- Hover cannot carry required behavior because touch and keyboard users may
  never trigger it.
- Placeholder text is not a label. Preserve field identity after entry begins.
- Animation must explain state or spatial change, respect reduced-motion
  settings, and never delay routine work.
- Mobile adaptation is task prioritization, not desktop compression.
