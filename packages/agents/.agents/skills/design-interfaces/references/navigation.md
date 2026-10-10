# Navigation, Signposts, And Wayfinding

Design navigation before styling it. Separate global, utility, associative,
inline, related-content, tag, and social routes by purpose. Minimize cognitive
load and travel distance, preserve orientation, and let destinations advertise
their meaning before selection.

Choose a model deliberately: hub-and-spoke for repeated returns to a center;
fully connected for a small peer set; tree for nested content; step-by-step for
dependent sequences; pyramid for overview-to-detail with cross-links; flat for a
small top-level set.

## Patterns

### Clear Entry Points
Present a small set of distinct starting paths when people arrive with different
goals. Use plain labels and representative cues; avoid competing calls to action.

### Menu Page
Use a dedicated set of destinations when the choices themselves are the main
task, especially on constrained screens. Group and order choices by user intent,
not organizational ownership.

### Pyramid
Connect overview, category, and detail levels while allowing useful lateral
movement. Keep the hierarchy legible and provide a stable route upward.

### Modal Panel
Temporarily focus a bounded decision or task while retaining the underlying
context. Use only when interruption is justified, trap and restore focus
correctly, provide an obvious exit, and avoid stacking modals.

### Deep Links
Give meaningful states stable, shareable, restorable addresses. Encode the
minimum necessary state, handle missing permission or stale objects gracefully,
and preserve back-button expectations.

### Escape Hatch
Provide a reliable route to a safe, recognizable place from any deep or unusual
state. Preserve work or warn proportionally before abandoning it.

### Fat Menus
Expose several grouped destinations in a large menu when hierarchy is broad and
scanning is faster than drilling down. Keep groups stable, keyboard-operable,
and responsive; do not make the menu a second sitemap.

### Sitemap Footer
Offer a stable secondary map and institutional links at the end of long web
pages. Keep primary tasks elsewhere and ensure endless loading does not make the
footer unreachable.

### Sign-In Tools
Keep account identity, session state, sign-in, sign-out, and recovery easy to
find. Return people to their interrupted destination and distinguish account
switching from authentication.

### Progress Indicator
Show location and completion in a known sequence. Name meaningful stages, mark
current and completed steps, and avoid false precision when work is indeterminate.

### Breadcrumbs
Show the current location's hierarchy when people can enter deep structures or
move laterally. Each ancestor should navigate; do not use breadcrumbs as the only
back mechanism or for a history that is not hierarchical.

### Annotated Scroll Bar
Mark relevant positions, matches, errors, or collaborators along a long scrollable
space. Provide nonvisual equivalents and keep markers distinguishable at scale.

### Animated Transition
Use motion to explain continuity, hierarchy, cause, or spatial change. Keep it
brief, interruptible, and reduced-motion aware; never make animation the only
signal or delay routine navigation.

## Review Checklist

- Can people answer where they are, what is nearby, and how to leave?
- Does browser or platform back behavior match the visible model?
- Are deep states restorable and shareable where appropriate?
- Are modal and animated transitions necessary, accessible, and reversible?
- Does navigation remain operable at every supported viewport and input method?
