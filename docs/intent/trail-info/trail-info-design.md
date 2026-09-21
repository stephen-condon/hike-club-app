---
parent: high-level-design
prefix: TRAIL
---

# Trail Info

## Context and Design Philosophy

Everything else in this app is on-device. This segment is the single exception: an owner-triggered, read-only lookup against a private Hike Club API that returns a trail map, a meeting point, the intended trails, and a weather forecast for a planned hike.

The exception is kept narrow on purpose. Nothing fetched is ever written to SwiftData — the response lives in view state and disappears when the view does. No pack data is sent; the request carries an id and a key and nothing else. If the API is unreachable, unconfigured, or deleted tomorrow, every other segment works exactly as before.

Because the response comes from outside and the key is a real secret, the segment carries a set of security properties that are load-bearing rather than incidental. They are enumerated below so that a change which breaks one is visible as a change.

## Configuration

Two pieces, stored differently by sensitivity:

| Setting | Storage | Why |
|---------|---------|-----|
| Base URL | `UserDefaults` via `@AppStorage` | Not secret |
| API key | Keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | Secret; never in git, the binary, or an iCloud backup |

Both are entered in `SettingsView`, which is the only place either is writable. The key is never read back into the field — only a masked "set" state is shown.

`HikeAPI.config` (`HikeAPI.swift:128-133`) is the gate: it yields a usable pair only when the URL parses, its scheme is `https`, and a non-empty key exists. A nil config disables the fetch UI entirely (`TrailInfoView.swift:28`).

## Security Properties

These are the invariants to preserve:

1. **https only.** Enforced in `HikeAPI.config` (`:130`), so the key can never be sent to an http or malformed host. `SettingsView.swift:19-21` also warns, but that warning is advisory — it does not block saving, and the enforcement that matters is the config gate.
2. **Path-escape rejection.** `fetch(id:)` trims and rejects ids containing `/`, `?`, or `#` before building the URL, then uses `URL.appending(path:)` which percent-encodes the segment (`:137-144`).
3. **Response size cap.** 5 MB (`:125,168`) — a sanity bound on a display payload.
4. **No markdown or link injection.** Remote strings render as `Text(variable)`, never as interpolated markdown.
5. **https gating before navigation or image load.** `TrailInfoView.swift:62` (map image), `:85` (Google Maps `Link`), `:151` (map fetch) each check the scheme on a URL that came from the untrusted response.
6. **No ATS exception** in the app's Info.plist.

## Hike Identity

A hike links to the API through `Hike.apiHikeID`, which is the picked location's `short_name` slug — undated, because the API keeps one record per location and updates it in place, so the id stays stable across reschedules.

The id is never typed by hand. `HikeDetailView`'s location picker (`:87-93`) sets it from the cached location list, and only while the hike is `planned`.

`HikeID.normalize` (`HikeID.swift:19-27`) strips a legacy `yyyy-MM-dd-` prefix when it finds one, so hikes saved under the previous dated scheme still resolve without a store migration. It is pure and unit-tested.

**Current-state divergence:** the project's `CLAUDE.md` still documents the superseded scheme — `HikeID.make(date:slug:)`, `HikeID.slug(from:)`, `"yyyy-MM-dd-<slug>"` ids, and an `.onChange(of: hike.date)` re-sync. None of those exist. The comment at `HikeDetailView.swift:86` repeats the old scheme too.

## API Surface

Version 2, declared per request via `x-api-version: 2`; omitting it would yield v1.

| Endpoint | Returns | Used for |
|----------|---------|----------|
| `GET /hike/{id}` | `HikeResponse` | Trail info for one hike |
| `GET /hike-locations` | `[{short_name, full_name}]` | The location picker |

`HikeResponse` carries start/end times, meeting point, trails, a signed map URL with an expiry, and optional v2 weather (`startTempF`/`endTempF`, `precipitation` with probability/expected/window, `heatIndexF`, `windChillF`, alerts). Dates decode as ISO-8601. The location payload is snake_case while the hike payload is camelCase, so `HikeLocation` carries explicit `CodingKeys`.

Status mapping: 200 proceeds; 401, 404, and anything else map to distinct `HikeAPIError` cases with owner-readable messages.

## Location Cache

Locations are cached in `UserDefaults` and refreshed when older than 7 days. `refreshLocationsIfStale` (`:202-207`) is deliberately sticky: on any failure it keeps what it has, because a stale location list is far more useful than an empty picker on a trailhead with no signal. The cache is cleared only by the explicit Settings button.

A successful fetch can return an empty list: the API serves whatever list the admin holds, and the admin allows an empty one to mean no location is set up yet. The cache therefore has three states, told apart by the fetch date rather than the count:

| State | Signal | Hike detail (planned) | Settings → Cached |
|---|---|---|---|
| Never fetched | no fetch date | picker only | `none` |
| Fetched, empty | fetch date, zero locations | picker plus the footnote "Locations loaded — none are set up yet." | `0 · {date}` |
| Fetched | fetch date, one or more locations | picker only | `{count} · {date}` |

An empty result replaces the cache like any other successful fetch — the server's list is the organizer's current statement, and keeping an older list would offer locations the admin has removed. The note exists so that an empty picker after a successful load does not read as a failed one. An empty cache follows the same seven-day refresh as any other; the Settings clear button, enabled whenever a fetch date exists, is how the owner forces an earlier refetch.

`locationsAreStale(fetchedAt:now:)` and `LocationListState(count:fetchedAt:)`, which classifies the three states, are pure and unit-tested; the `UserDefaults` access is not.

**Current-state divergence:** the refresh swallows its error with `try?` (`:204`), so a permanently failing refresh is indistinguishable from a fresh cache. `SettingsView` shows a fetch date but no failure state.

## Rendering

`TrailInfoView` owns its own fetch state and renders into a `Section` on the hike detail page. Conditions pick an SF Symbol through `weatherSymbol(for:)`, a keyword heuristic over a free-form string — marked `ponytail:` at `HikeID.swift:31` with "swap for a `switch` if the API ever pins conditions to an enum."

The map image is fetched exactly once per fetch and held as a `UIImage`, then handed to `ZoomableImageView` for full-screen pinch/pan/double-tap. Passing the loaded image rather than the URL means zooming can never fail on an expired signed URL. `ZoomableScrollView` wraps `UIScrollView` so the gestures are the platform's, not reimplemented.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Network at all | One read-only endpoint pair | Fully offline; two-way sync with Scoutbook | Trail and weather data has no on-device source; nothing needs to leave the phone |
| Response persistence | Ephemeral view state | Cache in SwiftData; persist last fetch | Forecasts go stale; a stored one would mislead |
| Key storage | Keychain, device-only | `UserDefaults`; Info.plist; compiled in | It is a real secret and must not sync or ship |
| https enforcement point | `HikeAPI.config` | UI validation only | UI validation can be bypassed; the config gate cannot |
| Hike id scheme | Undated location slug | `yyyy-MM-dd-<slug>` (previous); server-issued id | The API keeps one record per location and updates in place, so the date made the id churn on reschedule |
| Legacy ids | Normalize on read | Store migration; leave broken | A pure prefix-strip costs nothing and needs no migration |
| Id entry | Location picker only | Free-text field | Eliminates typos and the path-escape class outright |
| Linking window | `planned` only | Any status; until `complete` | `[inferred]` — matches date editability, but no rationale is recorded |
| Location cache on failure | Keep stale data | Clear; show an error | An offline trailhead is exactly when the picker is needed |
| Empty location list from the server | Cache it and say it loaded with none | Keep the previous cache; show only an empty picker | An empty list is the organizer's current answer, so keeping an older list contradicts it; an unexplained empty picker looks like a failed fetch. |
| Cache clearing | Explicit Settings button only | TTL expiry; clear on error | Makes cache state something the owner controls deliberately |
| Weather symbol | Keyword heuristic | Exhaustive `switch`; server-supplied icon | The field is free-form; `ponytail:` names the upgrade |
| Map zoom | Pass the loaded `UIImage` | Re-fetch the URL in the zoom view | The URL is signed and expiring; re-fetching could fail after the image was already on screen |
| Test boundary | Pure helpers tested, I/O not | Mock `URLSession`; integration tests | Mirrors the split already used by `HealthImport` |

## Open Questions & Future Decisions

### Deferred
1. **CLAUDE.md and `HikeDetailView.swift:86` describe the superseded dated-id scheme.** Documentation fix, no code change.
2. **Silent location-refresh failure.** The owner cannot tell a stale cache from a current one. Surfacing a last-attempt or last-failure state in Settings would close it.
3. **A hike can only be linked while `planned`.** A hike started without a location can never get trail info. No rationale recorded.
4. **The Settings https warning does not block saving.** Harmless because `config` refuses, but the UI implies a validation it does not perform.
5. **No retry or offline affordance on the trail-info fetch itself** — a failure shows an alert and leaves the section empty.
6. **`weatherAvailable` and `weather != nil` are checked together** (`TrailInfoView.swift:99`). Whether the API can return one without the other is unknown.

## References

- `Pack134HikeClub/Pack134HikeClub/HikeAPI.swift`, `HikeID.swift`, `Keychain.swift`, `TrailInfoView.swift`, `ZoomableImageView.swift`, `SettingsView.swift`
- Arrow doc: `docs/arrows/trail-info.md`
- Related: [[hikes]], [[app-shell]]
