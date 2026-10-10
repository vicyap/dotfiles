# Showing Complex Data

Begin with the questions users must answer. Choose an organizational model,
visual encoding, scale, and interaction that makes relationships perceptible
without distorting values. Preattentive variables—position, length, size, color,
orientation, shape, and motion—should carry a small number of consistent
meanings.

Support overview, navigation, rearrangement, filtering, and exact-value access
according to the task. Label units and time ranges, expose missing or uncertain
data, and provide a table or textual equivalent when a chart cannot carry the
meaning accessibly.

## Patterns

### Datatips
Reveal exact values and local context on focus or pointer inspection without
covering the comparison target. Keep keyboard access and persistent alternatives
for touch and assistive technology.

### Data Spotlight
Emphasize one selected item while retaining surrounding context. Keep the
selection visible across linked views and avoid making unselected data disappear
when comparison matters.

### Dynamic Queries
Update results continuously as users adjust filters with immediate, stable
feedback. Show active constraints, result counts, reset, and no-result recovery;
throttle expensive requests without making state ambiguous.

### Data Brushing
Select a subset in one view and highlight the same records in related views.
Keep selection semantics and color consistent, support clearing and additive
selection, and expose a nonvisual summary.

### Multi-Y Graph
Compare related series with different scales only when separate axes are
necessary and unmistakable. Label axes and series directly and consider indexed
or normalized values before adding scales that can imply false relationships.

### Small Multiples
Repeat the same visual structure across subsets to support comparison. Share
scales and ordering where possible, keep panels compact, and make differences in
missing data explicit.

## Review Checklist

- Does the visual answer a defined question rather than merely display data?
- Are encodings, baselines, units, scales, and time windows honest and legible?
- Can users retrieve exact values and understand missing or uncertain data?
- Do filters and selections remain visible and synchronized across views?
- Is equivalent meaning available without color, hover, or fine pointer control?
