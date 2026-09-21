# Arrow: trail-info

Optional read-only trail, map and weather lookup from the Hike Club API — the app's only network call.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out. **Known doc drift** — see finding 1.

## References

### HLD
- docs/high-level-design.md (§ The one network call)

### LLD
- docs/intent/trail-info/trail-info-design.md

### EARS
- docs/intent/trail-info/trail-info-specs.md *(not yet drafted)*

### Tests
- Pack134HikeClub/Pack134HikeClubTests/HikeAPITests.swift

### Code
- Pack134HikeClub/Pack134HikeClub/HikeAPI.swift
- Pack134HikeClub/Pack134HikeClub/HikeID.swift
- Pack134HikeClub/Pack134HikeClub/Keychain.swift
- Pack134HikeClub/Pack134HikeClub/TrailInfoView.swift
- Pack134HikeClub/Pack134HikeClub/ZoomableImageView.swift
- Pack134HikeClub/Pack134HikeClub/SettingsView.swift
- Pack134HikeClub/Pack134HikeClub/Models.swift:192 (Hike.apiHikeID)
- Pack134HikeClub/Pack134HikeClub/HikeDetailView.swift:35-54,87-103,217-220

## Architecture

**Purpose:** Let the owner pull trail conditions for a planned hike from a private API, without that call becoming a dependency of anything the app records.

**Key Components:**
1. `HikeAPI` — v2 client (`x-api-version: 2`) for `GET /hike/{id}` and `GET /hike-locations`, plus the UserDefaults location cache
2. `HikeID.normalize` — strips a legacy `yyyy-MM-dd-` prefix so pre-migration stored ids still resolve
3. `Keychain` — device-only storage for the API key; `SettingsView` is the sole entry point for base URL and key
4. `TrailInfoView` — ephemeral render of the response, with `ZoomableImageView` for the trail map
5. Location picker in `HikeDetailView` — sets `apiHikeID` from a cached location's `short_name`

## Spec Coverage

*(specs not yet drafted — regenerate this table after `trail-info-specs.md` lands)*

## Key Findings

1. **CLAUDE.md describes an id scheme that no longer exists.** It documents `HikeID.make(date:slug:)`, `HikeID.slug(from:)`, `"yyyy-MM-dd-<slug>"` ids, and an `.onChange(of: hike.date)` re-sync. The code has only `HikeID.normalize` (`HikeID.swift:19-27`) and ids are bare location slugs as of commit `a9c0477`. The stale comment at `HikeDetailView.swift:86` repeats the old scheme.
2. **The security invariants are all present and locatable** — https-only base URL enforced in `HikeAPI.config` (`HikeAPI.swift:130`), device-only Keychain accessibility (`Keychain.swift:28`), path-escape rejection before `appending(path:)` (`HikeAPI.swift:137-144`), 5 MB response cap (`:125,168`), and https gating before `Link`/image load (`TrailInfoView.swift:62,85,151`).
3. **The Settings https check is advisory; the real gate is in `config`** — `SettingsView.swift:19-21` only renders a warning and does not block saving, so the enforcement that matters is `HikeAPI.swift:130` refusing to build a config at all.
4. **The location cache is deliberately sticky** — `HikeAPI.swift:202-207` keeps stale data on any fetch failure; only the Settings button clears it (`:196`).
5. **Location refresh failures are silent** — `:204` uses `try?` and discards the error, so a permanently failing refresh looks identical to a fresh cache.
6. **Responses are ephemeral by construction** — `TrailInfoView.swift:17-23` holds them in view `@State`; nothing writes them to SwiftData.
7. **The map image is fetched once per fetch and handed to the zoom view** — `TrailInfoView.swift:147-158`, so zooming can never fail on an expired signed URL.
8. **A hike can only be linked while `planned`** — `HikeDetailView.swift:87` shows the picker only in that state. A hike started without a location can never be linked afterward.

## Work Required

### Must Fix
1. Reconcile CLAUDE.md and the stale in-code comment with the current undated-slug id scheme (finding 1).

### Should Fix
2. Silent location-refresh failure gives the owner no way to tell a stale cache from a current one (finding 5).
3. Planned-only linking has no stated rationale and no escape hatch (finding 8).
