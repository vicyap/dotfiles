# User Interface Systems And Atomic Design

Use a design system to encode repeated decisions, not to erase product context.
Build from tokens and primitive controls through composed components, recurring
patterns, templates, and screens. Keep semantics, behavior, accessibility, and
content guidance alongside appearance.

## Component-System Guidance

- Begin with real repeated uses; do not abstract a one-off interface prematurely.
- Define component responsibility, supported states, content constraints,
  interaction contract, and composition boundaries.
- Prefer platform and project primitives before introducing another framework.
- Keep tokens semantic so themes and modes can change without renaming intent.
- Make variants represent genuine product distinctions, not arbitrary styling
  switches.
- Document loading, empty, error, disabled, validation, focus, selected, and
  destructive states as part of the component API.
- Test components alone and in representative compositions; a correct atom can
  still create a broken workflow.

## Atomic Hierarchy

- **Foundations or tokens:** color roles, typography, spacing, motion, elevation,
  shape, and breakpoints.
- **Primitives:** labels, icons, buttons, inputs, links, and other indivisible
  semantic controls.
- **Components:** small compositions with one clear responsibility.
- **Patterns:** recurring arrangements that solve a product interaction problem.
- **Templates:** structural layouts with defined regions and responsive behavior.
- **Screens:** templates populated with real content, permissions, and state.

Use the hierarchy as a communication aid, not a required folder structure.

## Framework Selection

Adopt or extend a UI framework when its platform support, accessibility,
customization model, maintenance, and component semantics fit the product. Audit
behavior and generated markup rather than trusting screenshots or component
counts. Avoid wrapping every dependency preemptively; add local abstractions only
where the product has a stable repeated contract.

## Review Checklist

- Are repeated decisions encoded once at the correct level?
- Do components expose semantic intent rather than styling internals?
- Are behavior, state, accessibility, and content constraints documented?
- Can patterns compose without nested focus, duplicated landmarks, or conflicting
  responsive rules?
- Does the system make the common product path easier than bypassing it?
