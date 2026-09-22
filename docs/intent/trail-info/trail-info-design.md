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

**Current-state divergence:** the project's `CLAUDE.md` still documents the superseded scheme — `HikeID.make(date:slug:)`, `HikeID.slug(from:)`, `"yyyy-MM-dd-<slug>"` ids, and an `.onChange(of: hike.date)` re-sync. None of those exist.

## API Surface

Version 3, declared per request via `x-api-version: 3`; omitting it would yield v1.

| Endpoint | Returns | Used for |
|----------|---------|----------|
| `GET /hike/{id}?start=&end=` | `HikeResponse` | Trail info for one hike |
| `GET /hike-locations` | `[{short_name, full_name}]` | The location picker |

The hike's date lives only here, in the app — the API's own record carries none under v3. `HikeAPI.fetch(id:start:end:)` sends `[[hike].date, [hike].effectiveEndTime]` as RFC 3339 `start`/`end` query parameters, formatted with the *device's* offset (`HikeAPI.windowFormatter`), since the API has no timezone of its own to fall back on. A malformed or inverted window is a `400`, mapped to `HikeAPIError.badWindow`.

`HikeResponse` carries no `start`/`end` (the app already knows the window it asked for) — meeting point, trails, a nullable signed map URL with a `mapAvailable` flag, and optional v3 weather (`startTempF`/`endTempF`, `startConditions`/`endConditions`, `precipitation` with probability/expected/window, `heatIndexF`, `windChillF`, alerts). Dates that remain (map `expiresAt`, precipitation window) decode as ISO-8601. The location payload is snake_case while the hike payload is camelCase, so `HikeLocation` carries explicit `CodingKeys`.

Status mapping: 200 proceeds; 400, 401, 404, 410, and anything else map to distinct `HikeAPIError` cases with owner-readable messages. A 400 means different things on the two endpoints the app calls — a rejected `start`/`end` window on `/hike/{id}`, but never on `/hike-locations`, which takes no query parameters — so the caller supplies which error a 400 means; `fetch` passes the window-specific message, `fetchLocations` the generic server one. 410 means the app's declared `x-api-version` is past its sunset and is no longer served at all, distinct from the advisory `Sunset` header below — it always means "update the app."

## Version Sunset

The API advertises a deprecated version's retirement with `Deprecation`, `Sunset`, and `Link` response headers (see the workspace's `docs/system-design.md`) before it starts responding 410. Every successful or error response is checked for a `Sunset` header: when present, its date is parsed and stored in `UserDefaults`; when absent, any previously stored date is cleared, so the note below disappears once the app is back on a current version. The three headers, when present, are also logged once per response via `os.Logger` — visibility that stops at the device's own Console unless someone goes looking, which is why the Settings note exists too.

While a sunset date is stored, Settings shows it next to the API configuration: "API version 3 retires on \<date\>. Update the app before then." This is the only owner-visible warning of an approaching cutoff; the 410 handling above is what happens if the app is still in the field after the cutoff passes.

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

`TrailInfoView` owns its own fetch state and renders into a `Section` on the hike detail page. Conditions pick an SF Symbol through `weatherSymbol(for:)`, a keyword heuristic over a free-form string — marked `ponytail:` at `HikeID.swift:31` with "swap for a `switch` if the API ever pins conditions to an enum." `startConditions` and `endConditions` render as one row (`conditionsSummary(start:end:)`, `HikeID.swift`): the phrase alone when the two match (case-insensitive), or `"<start> → <end>"` when they differ, so a hike that starts clear and ends in thunderstorms reads as one line rather than two. The row's icon is whichever end's `weatherSymbol` ranks more severe on a fixed severity ordering (thunder/snow > rain > fog > overcast > partly cloudy > clear), so the icon always names the worse condition the scout will face.

Each alert's icon comes from its `type` (`alertSymbol(for:)`, `HikeID.swift`) — `precip`, `heat_index`, and `wind_chill` each get a matching symbol; `nws_alert` and any type the app doesn't recognize fall back to the warning triangle used for all alerts before this, so a new server-side alert type still renders.

A response's `map` is nullable under v3: `nil` renders "No map for this trail" (the map image never uploaded), distinct from a present map at a non-`https` URL or one that fails to load, both of which render "Map unavailable" as before.

The map image is fetched exactly once per fetch and held as a `UIImage`, then handed to `ZoomableImageView` for full-screen pinch/pan/double-tap. Passing the loaded image rather than the URL means zooming can never fail on an expired signed URL. `ZoomableScrollView` wraps `UIScrollView` so the gestures are the platform's, not reimplemented.

Because the fetched response answers for the window it was requested with, editing the hike's Starts/Ends pickers after a fetch clears the displayed info (map image included) rather than leaving it on screen mislabeled as current — the section reverts to its pre-fetch "Fetch trail info" state and the owner fetches again for the new window. This is deliberately not an auto-refetch: fetching stays owner-triggered.

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
| Hike window ownership | The app sends `start`/`end` per request (v3) | Keep the date on the API record (v2); a server-side "current hike" concept | The API's own record carries no date at all under v3 — see [[hikes]] and the API's `system-design.md`. The app is the only place a hike's date lives, so it is the only place that can send it. |
| Window timestamp offset | The device's own `TimeZone.current` | UTC; the (unknown to the app) preserve's offset | The app has no way to know a preserve's timezone; the device's own offset is the only one it can state truthfully. |
| 400 scope | Caller-supplied error (window message on `/hike`, generic on `/hike-locations`) | One shared "check start/end" message for any 400 | `/hike-locations` takes no query parameters, so a 400 there can never mean a bad window; a shared message would misdirect the owner. |
| Sunset visibility | Settings note + one `os.Logger` line per response | Log only (issue's literal ask); a blocking alert | A log-only warning is invisible on a personal device nobody is watching in Console; a blocking alert is disruptive for a date over a month out. Settings is where the owner already looks to manage the API config. |
| 410 handling | Distinct "update the app" error | Reuse the generic server-problem message | 410 has one specific, actionable cause (a retired version) that the generic message would hide. |
| Start/end conditions display | One row, arrow between phrases when they differ, icon from the more severe end | Two separate rows (start conditions with icon, end conditions plain) | A hike that starts clear and ends in storms is one fact ("it gets worse"), not two rows to cross-reference; the icon should warn about the worse condition, not just the first. |
| Alert icon | Matched to the alert's `type` | One warning-triangle icon for every alert | The API already classifies each alert (`precip`/`nws_alert`/`heat_index`/`wind_chill`); a shared icon throws that classification away. |
| Stale info after a window edit | Clear the fetched response on any Starts/Ends change | Leave it on screen; auto-refetch | Leaving it on screen understates that it answered for the old window; auto-refetch would make the network call owner-triggered no longer. |

## No-Map State

Under v3, `map` is nullable and paired with a `mapAvailable` flag. `TrailInfoView` shows one of three states for the map slot: the loaded image (with zoom), "Map unavailable" (an `https` map present but its image failed to load, or a non-`https` URL rejected outright), or "No map for this trail" (`map` is `nil` — the hike's map image was never uploaded). This closes the app half of `api:API-RESP-010`.

## Open Questions & Future Decisions

### Deferred
1. **CLAUDE.md describes the superseded dated-id scheme.** Documentation fix, no code change.
2. **Silent location-refresh failure.** The owner cannot tell a stale cache from a current one. Surfacing a last-attempt or last-failure state in Settings would close it.
3. **A hike can only be linked while `planned`.** A hike started without a location can never get trail info. No rationale recorded.
4. **The Settings https warning does not block saving.** Harmless because `config` refuses, but the UI implies a validation it does not perform.
5. **No retry or offline affordance on the trail-info fetch itself** — a failure shows an alert and leaves the section empty.
6. **`weatherAvailable` and `weather != nil` are checked together** (`TrailInfoView.swift:99`). Whether the API can return one without the other is unknown.

## References

- `Pack134HikeClub/Pack134HikeClub/HikeAPI.swift`, `HikeID.swift`, `Keychain.swift`, `TrailInfoView.swift`, `ZoomableImageView.swift`, `SettingsView.swift`
- Arrow doc: `docs/arrows/trail-info.md`
- Related: [[hikes]], [[app-shell]]
