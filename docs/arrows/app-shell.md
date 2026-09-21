# Arrow: app-shell

App entry, tab navigation, splash, and the launch sequence that seeds the store and reschedules reminders.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out. **No test coverage.**

## References

### HLD
- docs/high-level-design.md (§ App shell)

### LLD
- docs/intent/app-shell/app-shell-design.md

### EARS
- docs/intent/app-shell/app-shell-specs.md *(not yet drafted)*

### Tests
*(none)*

### Code
- Pack134HikeClub/Pack134HikeClub/Pack134HikeClubApp.swift
- Pack134HikeClub/Pack134HikeClub/ContentView.swift
- Pack134HikeClub/Pack134HikeClub/SplashView.swift

## Architecture

**Purpose:** Stand the app up — open the store, run first-launch seeding, get reminders scheduled, and present the five tabs.

**Key Components:**
1. `Pack134HikeClubApp` — declares the seven-model `Schema`, builds the `ModelContainer`, and owns the launch sequence
2. Launch sequence — `Seed.seedIfNeeded` synchronously, then a `Task` that requests notification authorization and reschedules ceremony reminders
3. `ContentView` — the five-tab `TabView` and the splash overlay
4. `SplashView` — fixed-duration branded overlay

## Spec Coverage

*(specs not yet drafted — regenerate this table after `app-shell-specs.md` lands)*

## Key Findings

1. **The launch sequence has a real ordering dependency** — `Pack134HikeClubApp.swift:31-43` seeds before fetching scouts/hikes/inventory for `stickBuyCount`, so a first launch schedules reminders against the freshly seeded roster. The ordering is load-bearing and uncommented. `[inferred]`
2. **`try!` on `ModelContainer`** — `:23`. A store that cannot open crashes at launch with no recovery, no migration path, and no message. This is the app's single point of failure.
3. **The splash is a fixed 1.5s overlay, not a readiness signal** — `ContentView.swift:31`. It runs concurrently with seeding rather than waiting for it; on a slow first launch the tabs can appear before seeding finishes.
4. **Notification authorization is requested on every launch** — `:33`. `requestAuthorization` is idempotent at the OS level, so this is harmless but unconditional.
5. **Reminder rescheduling happens both here and in `CeremoniesView.onAppear`** — the launch pass exists to cover the case where the owner never opens the Ceremonies tab.
6. **Zero tests.** The only segment with no coverage; the ordering in finding 1 is entirely unverified.

## Work Required

### Should Fix
1. No recovery or diagnostic when the store fails to open (finding 2).

### Nice to Have
2. Tie splash dismissal to seeding completion rather than a fixed timer (finding 3).
3. Cover the launch-sequence ordering with a test (findings 1, 6).
