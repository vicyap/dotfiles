# Lists And Collections

Choose a representation based on what people need to perceive: text and metadata,
visual identity, hierarchy, order, comparison, selection, or direct action. Make
sorting, filtering, selection, and loading state explicit. Preserve position and
identity when items update.

## Patterns

### Two-Panel Selector Or Split View
Keep a collection and the selected item's details visible together when people
scan or switch repeatedly. Maintain selection and responsive fallback; do not
cramp either pane below useful width.

### One-Window Drilldown
Replace the collection with one item's details when space is constrained or
focus matters. Preserve list state, filters, and scroll position for return.

### List Inlay
Expand details or controls inside the list while retaining surrounding context.
Use for short, bounded content; prevent expansion from causing disorientation or
ambiguous selection.

### Cards
Group the image, summary, metadata, and actions of a coherent object. Establish a
clear click target and hierarchy; avoid nested interactive areas with conflicting
behavior.

### Thumbnail Grid
Use images as the primary recognition cue and arrange peers for visual scanning.
Keep labels and selection accessible, handle varying aspect ratios, and offer a
denser alternative when metadata comparison matters.

### Carousel
Place a small ordered set in a horizontally advancing viewport when focused
consumption matters more than overview. Provide controls, position, keyboard and
touch support; avoid auto-advance and hidden essential choices.

### Pagination
Divide a stable, addressable result set into explicit pages when position,
comparison, return, or bounded loading matters. Preserve query state and expose
total or range when trustworthy.

### Jump To Item
Provide direct movement to a known item or section in a long ordered collection.
Accept user vocabulary, keep focus synchronized, and expose the current position.

### Alpha Or Numeric Scroller
Offer rapid movement through a long collection with a meaningful alphabetical or
numeric order. Supply labels and keyboard equivalents; do not apply it to weak or
unstable ordering.

### New-Item Row
Place creation at the natural boundary of the collection when adding is frequent
and simple. Distinguish the draft from saved items, validate in context, and
preserve it through recoverable errors.

## Review Checklist

- Does the representation expose the attributes users compare or recognize?
- Are ordering, filters, counts, loading, empty, and selection states visible?
- Can users return to the same place after inspecting or editing an item?
- Are bulk actions scoped to the visible selection and safely reversible?
- Is virtualization or incremental loading transparent to focus and navigation?
