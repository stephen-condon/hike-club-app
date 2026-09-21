# Trail Info — EARS Specs

## Configuration

- [x] **TRAIL-001**: The system shall store the Hike Club API base URL in user defaults and the Hike Club API key in the device Keychain.
- [x] **TRAIL-002**: The system shall store the Hike Club API key with device-only accessibility, so it is never synced to iCloud.
- [x] **TRAIL-003**: The system shall treat the Hike Club API as configured only where the stored base URL parses, uses the https scheme, and a non-empty API key is stored.
- [x] **TRAIL-004**: If the stored Hike Club API base URL does not use the https scheme, then the system shall treat the API as unconfigured and issue no request to it.
- [x] **TRAIL-005**: While the base URL entered in Settings is non-empty and does not use the https scheme, the Settings view shall warn the owner.
- [x] **TRAIL-006**: The Settings view shall never display a stored Hike Club API key, showing only whether one is set.
- [x] **TRAIL-007**: When the owner saves a Hike Club API key, the system shall replace any key already stored for that account.
- [x] **TRAIL-008**: While a Hike Club API key is stored, the Settings view shall offer to clear it.
- [x] **TRAIL-009**: While the Hike Club API is not configured, the trail info section shall tell the owner to set the base URL and key in Settings and shall offer no fetch.

## Requests

- [x] **TRAIL-010**: The system shall send the stored API key as an x-api-key header and the value 2 as an x-api-version header on every Hike Club API request.
- [x] **TRAIL-011**: When the owner fetches trail info for a hike, the system shall issue a GET request to /hike/{id} using that hike's API id.
- [x] **TRAIL-012**: If a hike's API id is empty, or contains a slash, question mark, or hash character, then the system shall reject the trail info request without issuing it.
- [x] **TRAIL-013**: When building a Hike Club API request URL, the system shall append the hike id as a percent-encoded path segment rather than concatenating it into the URL string.
- [x] **TRAIL-014**: If a Hike Club API response body exceeds 5 MB, then the system shall reject that response.
- [x] **TRAIL-015**: If a Hike Club API request returns status 401, then the system shall report that the API key was rejected.
- [x] **TRAIL-016**: If a Hike Club API request returns status 404, then the system shall report that no hike with that id exists on the server.
- [x] **TRAIL-017**: If a Hike Club API request returns any other non-200 status, or a response that is not an HTTP response, then the system shall report a server problem.
- [x] **TRAIL-018**: The system shall decode date-time fields in Hike Club API responses as ISO-8601.
- [x] **TRAIL-019**: The system shall decode the hike-locations payload's snake_case short_name and full_name fields.
- [x] **TRAIL-020**: If a Hike Club API response cannot be decoded, then the system shall report the failure and leave the trail info section unchanged.
- [x] **TRAIL-021**: The system shall never persist a fetched trail info response.
- [x] **TRAIL-022**: The system shall issue no network request other than Hike Club API trail-info and hike-locations requests and the trail map image fetch.

## Hike Identity

- [x] **TRAIL-023**: The system shall set a hike's API id from the short name of a location the owner picks, never from text the owner types.
- [x] **TRAIL-024**: While a hike is planned, the system shall offer the location picker for that hike; in every other state it shall display that hike's selected location read-only.
- [x] **TRAIL-025**: When reading a hike's API id, the system shall strip a leading yyyy-MM-dd- date prefix where one is present, so hikes saved under the earlier dated scheme still resolve.
- [x] **TRAIL-026**: When a hike's API id carries no leading yyyy-MM-dd- date prefix, the system shall use that id unchanged.
- [x] **TRAIL-027**: While a hike's selected location is absent from the cached location list, the system shall still offer that location as the current selection in the picker.
- [x] **TRAIL-028**: The system shall offer cached locations in the picker sorted by full name.

## Location Cache

- [x] **TRAIL-029**: The system shall cache the hike-locations list in user defaults together with the time it was fetched.
- [x] **TRAIL-030**: The system shall treat the cached location list as stale where it has never been fetched or was fetched more than seven days ago.
- [x] **TRAIL-031**: When a hike detail view appears and the cached location list is stale, the system shall attempt to refresh that list.
- [x] **TRAIL-032**: If refreshing the location list fails, then the system shall keep the existing cached list.
- [x] **TRAIL-033**: The system shall clear the cached location list only when the owner chooses to clear it in Settings.
- [x] **TRAIL-034**: The Settings view shall show how many locations are cached and when they were fetched.

## Display

- [x] **TRAIL-035**: The trail info section shall render text taken from a Hike Club API response as plain text, never as markdown and never as a link.
- [x] **TRAIL-036**: If a URL in a Hike Club API response does not use the https scheme, then the system shall neither load it nor offer it as a link.
- [x] **TRAIL-037**: When trail info is fetched for a hike, the system shall load that hike's trail map image once and pass the loaded image to the full-screen viewer, issuing no further request when the owner zooms.
- [x] **TRAIL-038**: If a hike's trail map image cannot be loaded, then the system shall show that the map is unavailable and leave the rest of that hike's trail info readable.
- [x] **TRAIL-039**: The system shall choose a weather symbol by matching keywords in a trail info response's free-form conditions string, falling back to a generic cloud symbol when no keyword matches.
- [x] **TRAIL-040**: Where a trail info response reports weather as available, the system shall show conditions, start and end temperatures, precipitation probability and expectation, and any alerts.
- [x] **TRAIL-041**: Where a trail info response reports weather as available and carries a precipitation window, the system shall show that window's start and end times.
- [x] **TRAIL-042**: Where a trail info response reports weather as available and carries a heat index or a wind chill, the system shall show them.
- [x] **TRAIL-043**: If a trail info response reports weather as unavailable, then the system shall state that weather is unavailable.
- [x] **TRAIL-044**: The trail info section shall show the meeting point's coordinates, and shall offer a maps link where the response's maps URL uses the https scheme.
- [x] **TRAIL-045**: The full-screen trail map viewer shall support pinch, pan, and double-tap zoom up to four times actual size.
