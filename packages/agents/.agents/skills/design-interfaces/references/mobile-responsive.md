# Mobile And Responsive Interfaces

Design for small variable screens, touch, difficult typing, interruption,
movement, connectivity changes, and divided attention. Prioritize the primary
task and adapt information density; do not preserve desktop composition at the
expense of comprehension.

## Patterns

### Vertical Stack
Place the main content and actions in a single scrollable sequence. Order by task
priority, keep related controls together, and use sticky elements sparingly.

### Filmstrip
Show a horizontal sequence with a clear current item and hints of adjacent items.
Use for ordered media or lightweight browsing, not for choices that require fast
comparison or undiscoverable horizontal scrolling.

### Touch Tools
Reveal direct manipulation controls near the selected object while retaining
visible, accessible alternatives. Avoid gesture-only commands and target overlap.

### Bottom Navigation
Place a small set of frequent peer destinations within thumb reach. Use stable
labels and icons, preserve each destination's state, and avoid using it for
commands or deep hierarchies.

### Collections And Cards
Represent coherent objects as scannable units that can reflow across widths.
Make the primary action and selection behavior unambiguous; do not turn every
section into a card.

### Infinite List
Load more items as the person approaches the end when ongoing discovery matters
more than position. Preserve return state, announce loading, prevent duplicate
content, and choose another model when users need boundaries or comparison.

### Generous Borders
Increase target size and separation beyond the visible mark. Prevent accidental
activation, keep hit areas nonoverlapping, and provide visible focus equivalents.

### Loading Or Progress Indicators
Respond immediately to touch, show determinate progress when measurable, and
keep the interface stable through network changes. Offer retry, cancellation, or
offline recovery appropriate to consequence.

### Richly Connected Apps
Use device capabilities, identity, sharing, location, and notifications to reduce
work or connect related tasks. Ask permission in context, explain value, minimize
data, and provide a manual fallback.

### Make It Mobile
Reframe the desktop task around mobile context and priority. Remove or defer
secondary work, adapt interaction and navigation, and preserve cross-device
continuity where users switch environments.

## Responsive Checklist

- Test narrow, medium, and wide layouts with realistic content expansion.
- Keep primary actions reachable without covering content or system UI.
- Provide alternatives for hover, right-click, drag, and precision gestures.
- Preserve state through rotation, resizing, interruption, and navigation.
- Handle slow, offline, denied-permission, and resumed states.
