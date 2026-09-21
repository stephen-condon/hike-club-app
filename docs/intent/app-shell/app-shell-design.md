---
parent: high-level-design
prefix: SHELL
---

# App Shell

## Context and Design Philosophy

The shell is small and does three things that nothing else can: it declares the schema, it runs the once-per-install setup, and it presents the tabs.

It earns a segment of its own because the launch sequence is real behavior with a real ordering, not glue. Seeding has to finish before reminders are computed, or the first launch schedules notifications against an empty roster. That dependency is invisible in the code and has no test.

The tab bar is the app's entire navigation model. There is no router, no deep linking, and no state restoration — five tabs, each owning a `NavigationStack`.

## Schema and Container

`Pack134HikeClubApp` (`:13-24`) declares the seven-model `Schema` — `Scout`, `Hike`, `Attendance`, `InventoryItem`, `StickAssignment`, `Ceremony`, `CeremonyAward` — and builds a default on-disk `ModelContainer`.

Adding a model means adding it here; a `@Model` class absent from this list is invisible to the container.

**Current-state divergence:** the container is built with `try!` (`:23`). A store that cannot open — a failed migration, a corrupted file — crashes at launch with no message and no recovery path. This is the app's single point of failure.

## Launch Sequence

On `ContentView.onAppear` (`:30-44`):

1. `Seed.seedIfNeeded(context:)` — synchronous, first-launch-only, populates roster and inventory
2. A `Task`:
   a. `CeremonyReminders.requestAuthorization()`
   b. Fetch ceremonies, active scouts, hikes, inventory
   c. `CeremonyReminders.reschedule(ceremonies, sticksToBuy: stickBuyCount(...))`

Step 1 must precede step 2c, since `stickBuyCount` reads the scouts and inventory that seeding creates. The ordering is load-bearing and uncommented.

This is the second of two reschedule triggers; the other is `CeremoniesView.onAppear`. The launch pass exists so reminders stay correct for an owner who never opens the Ceremonies tab. See [[ceremonies]].

Notification authorization is requested on every launch. `requestAuthorization` is idempotent at the OS level, so this is harmless but unconditional.

## Navigation and Splash

`ContentView` is a five-tab `TabView` — Hikes, Scouts, Inventory, Ceremonies, Settings — with `SplashView` layered over it in a `ZStack`.

The splash is a fixed 1.5-second overlay with a 0.4-second fade (`ContentView.swift:31-32`), driven by a timer rather than by readiness. It runs concurrently with seeding, so on a slow first launch the tabs can become visible before seeding completes.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Persistence | SwiftData, on-device | Core Data; SQLite; files | `requirements.md` asks for the standard local-iPhone choice; single user, single device |
| Architecture | No MVVM; views hold `@Query` and mutate models | View models per screen; a store layer | One user, one device, no async coordination to justify a layer |
| Container failure | `try!` | Fallback in-memory container; error screen | `[inferred]` — no handling exists; likely unexamined rather than chosen |
| Navigation | Five-tab `TabView` | Sidebar; single stack | Five coordinate domains, each with its own stack |
| Splash | Fixed-duration overlay | Launch screen only; readiness-gated | `[inferred]` — `notes.md` asked for a branded loading screen; the timer is the simplest thing that shows one |
| Seed trigger | `onAppear` in the shell | App init; first-run flag; background task | Needs a live `modelContext`, which the container provides here |
| Launch reschedule | At launch **and** on tab appear | Tab appear only | Covers an owner who never visits Ceremonies |
| Notification auth | Requested every launch | Once, flagged; on first ceremony creation | Idempotent at the OS level, so the simplest call site wins |

## Open Questions & Future Decisions

### Deferred
1. **No recovery when the store fails to open.** Deciding between a crash, an error screen, and an in-memory fallback is the one durability decision this app has not made.
2. **Splash is time-based, not readiness-based.** Tying dismissal to seeding completion would remove the race, at the cost of a variable-length splash.
3. **The launch ordering is untested and uncommented.** Findings 1 and 2 of the arrow doc both trace to this; a test pinning seed-before-reschedule would make the dependency visible.
4. **No state restoration.** The app always opens on the Hikes tab.
5. **Zero test coverage** — the only segment with none.

## References

- `Pack134HikeClub/Pack134HikeClub/Pack134HikeClubApp.swift`, `ContentView.swift`, `SplashView.swift`
- Arrow doc: `docs/arrows/app-shell.md`
- Related: [[scouts]], [[ceremonies]]
