# Event Storming and Event Modeling

Two related discovery techniques that belong *before* anyone writes a line of event-sourced code. Drop this file when the user asks "should we event-storm this?", "how do I figure out my events?", or "we did an event storming workshop, now what?"

## Why this comes before code

Bad early modeling is permanent in event sourcing because events can never be deleted. Production systems that committed to ES before deeply event-storming the domain end up with dozens of deprecated event types accumulated forever — a permanent tax on every consumer that has to keep handling them.

The rule:

> **There should be a clear one-to-one correspondence between what you model in your event storming sessions and what you actually store in your event source.**

If the team has not run a discovery workshop, do that first. The rest of this skill assumes you know which events exist.

## Event Storming

A workshop format for collectively discovering domain events. Originally intended for DDD bounded-context discovery; widely used as the first step before event-sourced code.

The format in three escalating versions:

### Big Picture Event Storming

**Goal:** Map the entire domain at high level. Identify bounded contexts. Surface terminology disagreements between domain experts.

**Participants:** Wide — domain experts, product, ops, engineering. 5–20 people. Half a day to a day.

**Materials:** Long wall, orange sticky notes ("domain events"), markers.

**Procedure:**
1. Everyone writes domain events on orange stickies (past tense: `Order Placed`, `Payment Received`, `Customer Onboarded`).
2. Stickies go on the wall in rough chronological left-to-right order.
3. Cluster duplicates. Discuss disagreements — they reveal model misalignment.
4. Identify **pivotal events** that change the conversation (e.g., the moment money moves, the moment a contract is signed).
5. Use pivotal events to draw bounded-context lines.

**Output:** A wall covered in orange events, with vertical lines marking bounded-context boundaries.

### Process-Level Event Storming

**Goal:** Detail one bounded context. Surface commands, actors, policies, read models.

**Participants:** Smaller — domain experts + engineers for one context. 5–10 people. A day.

**Materials:** Add blue stickies (commands), yellow (actors), purple (policies), green (read models / external systems), red (problems / open questions).

**Procedure:** Walk the orange-event timeline left to right. For each event, identify:
- Blue: what command produced it? (Imperative: `Place Order`, `Reserve Funds`.)
- Yellow: which actor issued the command? (User, system, scheduler.)
- Purple: what policy reacted to this event? (`When OrderPlaced, ReserveFunds`.)
- Green: what read model did the actor consult before issuing the command?
- Red: open questions, contradictions, things to investigate.

**Output:** A storyboard: actor → command → event → policy → next command, with read models hanging off where needed. This is *very close* to a runnable design.

### Software Design Event Storming

**Goal:** Design the system that implements the process. Identify aggregates.

**Participants:** Engineers + a few domain experts. 3–8 people. Half a day.

**Procedure:** Group commands and events by **transactional consistency boundaries** — the aggregate boundaries. Each cluster becomes one aggregate. Commands inside an aggregate are synchronous; cross-aggregate is eventual via policies.

**Output:** Aggregate definitions. The list of events per aggregate. The cross-aggregate policies that route events to commands.

## Event Modeling

Builds on Event Storming and Greg Young's CQRS/ES "long-running process" specifications. The output is more like a screenplay than a brainstorm — deliberately structured for *implementation*, not just discovery.

The notation:

- **Pages = wireframes** of the screens / API endpoints users interact with.
- **Yellow stickies = commands** issued from those screens.
- **Orange stickies = events** that result.
- **Green stickies = read models** queried by the screens.
- **Lines connect them in time order**, left to right, like a sideways storyboard.

Think of an event model as a captured screencast of someone using the system you intend to build. A reader walks the storyboard left to right and learns exactly what happens at each moment.

### How it differs from Event Storming

- **Concrete, not exploratory.** Every event must connect to a command (cause) and a read model (effect). No floating events.
- **Wireframe-anchored.** Every command originates at a screen or API call. Forces you to ground events in real user behavior.
- **Implementation-ready.** Reading the model gives you the list of commands, events, aggregates, and projections to build, in order.

### When to use each

- **Big Picture Event Storming** when bounded contexts aren't clear yet, or different teams use different language for the same concept.
- **Process-Level Event Storming** when one bounded context is being designed and you want to surface policies and edge cases before code.
- **Software Design Event Storming** when you've decided to build it and need aggregate shapes.
- **Event Modeling** when you have wireframes (or can sketch them) and want a deliverable that drives implementation directly. Especially good with a small team committed to event sourcing.

Most teams do some of each, in order: Big Picture → Process Level → Event Modeling for the parts being built next.

## Common workshop failure modes

- **The domain expert isn't in the room.** Skip the workshop until they are; the value is in their corrections.
- **Engineers steer the model toward the database.** "We need a User entity, not a UserOnboarded event." Push back: events are domain facts, not table rows.
- **Events get named after CRUD.** `UserCreated`, `OrderUpdated`. These are Clickbait Events ([anti-patterns.md](anti-patterns.md)). Re-name to specific business actions.
- **Stopping after Big Picture.** The orange-events-on-a-wall artifact is satisfying but not actionable. Always push to at least Process-Level before declaring victory.
- **Treating the output as final.** It's a snapshot of current understanding; revisit it whenever the model surprises you. Plan to run multiple sessions per bounded context as the model deepens.

## Bridging to code

After the workshop:

1. **Aggregate list** → one module / file per aggregate.
2. **Command list** → command structs (present tense: `PlaceOrder`).
3. **Event list** → event structs (past tense: `OrderPlaced`).
4. **Read model list** → projection schemas, one per screen.
5. **Policy list** → handlers / sagas that subscribe to events and emit commands.

The 1:1 mapping rule means: if a command appears in your code that's not on the workshop wall, push back. If an event is on the wall but no code emits it, the model is drifting.

## Further reading

- [eventmodeling.org](https://eventmodeling.org/about/) — Event Modeling notation, examples, and learning materials.
- *Introducing EventStorming* (Leanpub) — the canonical reference for the Event Storming workshop format.
