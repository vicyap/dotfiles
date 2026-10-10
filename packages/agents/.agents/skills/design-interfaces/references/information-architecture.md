# Information Architecture And Application Structure

Organize around recognizable objects and tasks, not backend services. Keep
categories mutually distinguishable and collectively useful, but accept overlap
when the domain genuinely has facets. Choose ordering—alphabetical, numeric,
temporal, geographic, hierarchical, or faceted—because it supports retrieval.

Use a small system of screen roles: overview, focus on one object, creation or
editing, and focused task completion. Keep frequent items visible, chunk long
jobs into meaningful stages, and separate information structure from its visual
presentation.

## Patterns

### Feature, Search, And Browse
Combine curated entry points, direct search, and navigable categories when people
arrive with different levels of intent. Make the three paths complementary and
keep filters reflected in results and URLs or state.

### Mobile Direct Access
Expose the few most valuable mobile destinations or actions immediately. Use
device context only when it reduces work and has clear permission and fallback.

### Streams And Feeds
Present time-ordered or relevance-ordered updates when recency and continued
discovery matter. Mark new state, preserve return position, explain ranking where
consequential, and provide boundaries or filters for control.

### Media Browser
Support browsing, previewing, filtering, selecting, and acting on visual or audio
assets without losing collection context. Keep metadata and actions close to the
active item.

### Dashboard
Place several changing measures or conditions in one monitoring view. Establish
priority, show units and time ranges, make anomalies actionable, and link summary
signals to detail. Do not use a dashboard as a decorative landing page.

### Canvas Plus Palette
Pair a large creation surface with organized tools or objects. Keep the canvas
primary, preserve tool state visibly, and provide keyboard and non-drag routes
for precise or accessible operation.

### Wizard
Guide an infrequent, ordered, multi-step task when later choices depend on earlier
ones. Show progress, allow safe backtracking, preserve entries, and avoid a wizard
for tasks experts repeat or steps that can be understood together.

### Settings Editor
Group durable preferences by user concept, distinguish account-wide from local
scope, expose effective values, and make consequences clear. Apply immediately
only when reversal is easy; otherwise provide an explicit save boundary.

### Alternative Views
Offer genuinely different representations of the same objects when tasks demand
them, such as list versus map. Preserve selection, filters, and position across
views; do not duplicate views that differ only cosmetically.

### Many Workspaces
Support several persistent contexts when people compare or switch among complex
tasks. Name, restore, and close them predictably; make unsaved or active state
visible and constrain proliferation.

### Help Systems
Place concise help at the point of need, then link to deeper explanation. Use
clear labels, examples, guided instruction, searchable reference, and community
support according to task complexity. Help must not compensate for avoidable UI
confusion.

### Tags
Allow flexible, overlapping classification when a single hierarchy is too rigid.
Suggest existing terms, handle synonyms, expose ownership or scope, and prevent
uncontrolled duplication from destroying retrieval value.

## Review Checklist

- Can users predict where an object or task belongs?
- Are overview, focus, creation, and task screens distinguishable?
- Does search complement rather than conceal the information structure?
- Are persistent contexts, filters, and preferences scoped and recoverable?
- Is advanced complexity deferred without hiding frequent work?
