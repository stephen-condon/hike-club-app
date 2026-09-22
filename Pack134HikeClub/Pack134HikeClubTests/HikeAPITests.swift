//
//  HikeAPITests.swift
//  Pack134HikeClubTests
//
//  Decode-side tests for the Hike Club API (v2) response and the pure id/cache/weather
//  helpers. The URLSession + Keychain + UserDefaults calls are device-only and not unit-tested
//  (mirrors HealthImportTests covering only the pure conversions).
//

import Testing
import Foundation
@testable import Pack134HikeClub

struct HikeResponseDecodeTests {

    // Full v3 payload: no start/end (the app supplied the window in the
    // request), weather with start/end temps and conditions, a non-expected
    // precip, and an alert.
    static let full = """
    {
      "id": "ridge-loop",
      "meetingPoint": { "lat": 40.7, "lon": -74.0, "googleMapsUrl": "https://maps.google.com/?q=40.7,-74.0" },
      "trails": ["Ridge Loop", "Creek Spur"],
      "map": { "url": "https://cdn.example.com/map.png", "expiresAt": "2026-08-01T18:00:00Z" },
      "mapAvailable": true,
      "weatherAvailable": true,
      "weather": {
        "startTempF": 62.5,
        "endTempF": 70.0,
        "startConditions": "Sunny",
        "endConditions": "Partly cloudy",
        "precipitation": { "probabilityPct": 20, "expected": false, "startsAt": null, "endsAt": null },
        "heatIndexF": null,
        "windChillF": null,
        "alerts": [ { "type": "heat_index", "message": "Heat advisory" } ]
      }
    }
    """

    // Rainy v3 payload: expected precip with a window + heat index / wind chill present.
    static let rainy = """
    {
      "id": "creek",
      "meetingPoint": { "lat": 1.0, "lon": 2.0, "googleMapsUrl": "https://maps.google.com/?q=1,2" },
      "trails": ["Creek"],
      "map": { "url": "https://cdn.example.com/m.png", "expiresAt": "2026-08-01T18:00:00Z" },
      "mapAvailable": true,
      "weatherAvailable": true,
      "weather": {
        "startTempF": 55.0,
        "endTempF": 48.0,
        "startConditions": "Cloudy",
        "endConditions": "Rain",
        "precipitation": {
          "probabilityPct": 80, "expected": true,
          "startsAt": "2026-08-01T15:00:00Z", "endsAt": "2026-08-01T16:00:00Z"
        },
        "heatIndexF": 60.0,
        "windChillF": 45.0,
        "alerts": []
      }
    }
    """

    // weatherAvailable false, weather null (the nullable path).
    static let noWeather = """
    {
      "id": "x",
      "meetingPoint": { "lat": 1.0, "lon": 2.0, "googleMapsUrl": "https://maps.google.com/?q=1,2" },
      "trails": [],
      "map": { "url": "https://cdn.example.com/m.png", "expiresAt": "2026-08-02T17:00:00Z" },
      "mapAvailable": true,
      "weatherAvailable": false,
      "weather": null
    }
    """

    // mapAvailable false, map null — the hike whose map image never uploaded.
    static let noMap = """
    {
      "id": "x",
      "meetingPoint": { "lat": 1.0, "lon": 2.0, "googleMapsUrl": "https://maps.google.com/?q=1,2" },
      "trails": [],
      "map": null,
      "mapAvailable": false,
      "weatherAvailable": false,
      "weather": null
    }
    """

    @Test func decodesFullPayload() throws {
        let r = try HikeResponse.decode(Data(Self.full.utf8))
        #expect(r.id == "ridge-loop")
        #expect(r.trails == ["Ridge Loop", "Creek Spur"])
        #expect(r.meetingPoint.lat == 40.7)
        #expect(r.meetingPoint.googleMapsUrl.scheme == "https")
        #expect(r.mapAvailable == true)
        #expect(r.map?.url.absoluteString == "https://cdn.example.com/map.png")
        #expect(r.weatherAvailable == true)
        #expect(r.weather?.startTempF == 62.5)
        #expect(r.weather?.endTempF == 70.0)
        #expect(r.weather?.startConditions == "Sunny")
        #expect(r.weather?.endConditions == "Partly cloudy")
        #expect(r.weather?.precipitation.probabilityPct == 20)
        #expect(r.weather?.precipitation.expected == false)
        #expect(r.weather?.precipitation.startsAt == nil)
        #expect(r.weather?.heatIndexF == nil)
        #expect(r.weather?.alerts.first?.message == "Heat advisory")
    }

    @Test func decodesPrecipWindowAndFeelsLike() throws {
        let r = try HikeResponse.decode(Data(Self.rainy.utf8))
        let w = try #require(r.weather)
        #expect(w.startTempF == 55.0)
        #expect(w.endTempF == 48.0)
        #expect(w.precipitation.expected == true)
        #expect(w.precipitation.probabilityPct == 80)
        #expect(w.precipitation.startsAt == ISO8601DateFormatter().date(from: "2026-08-01T15:00:00Z"))
        #expect(w.precipitation.endsAt == ISO8601DateFormatter().date(from: "2026-08-01T16:00:00Z"))
        #expect(w.heatIndexF == 60.0)
        #expect(w.windChillF == 45.0)
    }

    @Test func decodesISO8601Dates() throws {
        let r = try HikeResponse.decode(Data(Self.full.utf8))
        let expected = ISO8601DateFormatter().date(from: "2026-08-01T18:00:00Z")
        #expect(r.map?.expiresAt == expected)
    }

    @Test func decodesNullWeather() throws {
        let r = try HikeResponse.decode(Data(Self.noWeather.utf8))
        #expect(r.weatherAvailable == false)
        #expect(r.weather == nil)
        #expect(r.trails.isEmpty)
    }

    // @spec TRAIL-051
    @Test func decodesNullMap() throws {
        let r = try HikeResponse.decode(Data(Self.noMap.utf8))
        #expect(r.mapAvailable == false)
        #expect(r.map == nil)
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: (any Error).self) {
            try HikeResponse.decode(Data("{ not json".utf8))
        }
    }
}

// @spec TRAIL-010
struct WindowQueryItemsTests {
    @Test func formatsStartAndEndAsRFC3339WithTheDevicesOffset() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let end = start.addingTimeInterval(2 * 60 * 60)
        let items = HikeAPI.windowQueryItems(start: start, end: end)
        #expect(items.map(\.name) == ["start", "end"])
        #expect(items[0].value == HikeAPI.windowFormatter.string(from: start))
        #expect(items[1].value == HikeAPI.windowFormatter.string(from: end))
        // RFC 3339 with an offset, not the "Z" a UTC-pinned formatter would emit —
        // unless the device itself is in UTC, which CI runners typically are not.
        #expect(HikeAPI.windowFormatter.timeZone.secondsFromGMT() == TimeZone.current.secondsFromGMT())
    }

    @Test func endIsStrictlyAfterStart() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let end = start.addingTimeInterval(60)
        let items = HikeAPI.windowQueryItems(start: start, end: end)
        #expect(items[0].value != items[1].value)
    }
}

struct HikeLocationDecodeTests {

    static let json = """
    [
      { "short_name": "danada-equestrian-center", "full_name": "Danada Equestrian Center" },
      { "short_name": "cantigny-park", "full_name": "Cantigny Park" }
    ]
    """

    @Test func decodesSnakeCaseMapping() throws {
        let locs = try HikeLocation.decode(Data(Self.json.utf8))
        #expect(locs.count == 2)
        #expect(locs[0].shortName == "danada-equestrian-center")
        #expect(locs[0].fullName == "Danada Equestrian Center")
        #expect(locs[1].shortName == "cantigny-park")
    }
}

struct HikeIDTests {

    @Test func stripsLegacyDatePrefix() {
        #expect(HikeID.normalize("2026-07-25-danada-equestrian-center") == "danada-equestrian-center")
        #expect(HikeID.normalize("2026-09-19-mallard-lake-forest-preserve") == "mallard-lake-forest-preserve")
    }

    @Test func passesBareSlugThrough() {
        #expect(HikeID.normalize("cantigny-park") == "cantigny-park")
        #expect(HikeID.normalize("st-james-farm-forest-preserve") == "st-james-farm-forest-preserve")
    }

    @Test func leavesNonConformingIDAlone() {
        #expect(HikeID.normalize("") == "")
        #expect(HikeID.normalize("2026-07-25-") == "2026-07-25-")  // prefix only, no slug to strip to
        #expect(HikeID.normalize("not-a-date-cantigny") == "not-a-date-cantigny")
    }
}

struct LocationCacheStalenessTests {
    private let day: TimeInterval = 24 * 60 * 60

    @Test func nilFetchIsStale() {
        #expect(HikeAPI.locationsAreStale(fetchedAt: nil, now: Date()) == true)
    }

    @Test func sixDaysIsFresh() {
        let now = Date()
        #expect(HikeAPI.locationsAreStale(fetchedAt: now.addingTimeInterval(-6 * day), now: now) == false)
    }

    @Test func eightDaysIsStale() {
        let now = Date()
        #expect(HikeAPI.locationsAreStale(fetchedAt: now.addingTimeInterval(-8 * day), now: now) == true)
    }
}

// Staleness takes only the fetch date, so an empty list refreshes on the same schedule as any other.
// @spec TRAIL-050
struct EmptyLocationCacheStalenessTests {
    @Test func emptyListFetchedRecentlyIsFresh() {
        let now = Date()
        #expect(HikeAPI.locationsAreStale(fetchedAt: now.addingTimeInterval(-60), now: now) == false)
    }
}

struct LocationListStateTests {
    private let fetched = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func classifiesTheThreeStates() {
        #expect(LocationListState(count: 0, fetchedAt: nil) == .notFetched)
        #expect(LocationListState(count: 3, fetchedAt: nil) == .notFetched)
        #expect(LocationListState(count: 0, fetchedAt: fetched) == .empty(fetchedAt: fetched))
        #expect(LocationListState(count: 3, fetchedAt: fetched) == .loaded(count: 3, fetchedAt: fetched))
    }

    // @spec TRAIL-047, TRAIL-048
    @Test func emptyNoteShowsOnlyForAFetchedEmptyList() {
        #expect(LocationListState(count: 0, fetchedAt: fetched).showsEmptyNote)
        #expect(!LocationListState(count: 0, fetchedAt: nil).showsEmptyNote)
        #expect(!LocationListState(count: 2, fetchedAt: fetched).showsEmptyNote)
        #expect(LocationListState.emptyNote == "Locations loaded — none are set up yet.")
    }

    // @spec TRAIL-049
    @Test func clearingIsOfferedWheneverAFetchTimeIsRecorded() {
        #expect(LocationListState(count: 0, fetchedAt: fetched).canClear)
        #expect(LocationListState(count: 2, fetchedAt: fetched).canClear)
        #expect(!LocationListState(count: 0, fetchedAt: nil).canClear)
    }

    // @spec TRAIL-034
    @Test func settingsStatusShowsZeroOnceFetched() {
        let date = fetched.formatted(date: .abbreviated, time: .omitted)
        #expect(LocationListState(count: 0, fetchedAt: nil).cacheStatus == "none")
        #expect(LocationListState(count: 0, fetchedAt: fetched).cacheStatus == "0 · \(date)")
        #expect(LocationListState(count: 15, fetchedAt: fetched).cacheStatus == "15 · \(date)")
    }
}

// Isolated defaults suite per test, so the real cache is never touched.
struct LocationCacheStorageTests {
    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "LocationCacheStorageTests-\(UUID().uuidString)")!
    }

    // @spec TRAIL-046
    @Test func storingAnEmptyListReplacesTheCacheAndRecordsTheFetch() {
        let defaults = isolatedDefaults()
        HikeAPI.storeLocations([HikeLocation(shortName: "cantigny-park", fullName: "Cantigny")], in: defaults)
        HikeAPI.storeLocations([], in: defaults)
        #expect(HikeAPI.cachedLocations(in: defaults).isEmpty)
        #expect(HikeAPI.locationsFetchedAt(in: defaults) != nil)
    }

    @Test func neverStoredHasNoFetchTime() {
        let defaults = isolatedDefaults()
        #expect(HikeAPI.cachedLocations(in: defaults).isEmpty)
        #expect(HikeAPI.locationsFetchedAt(in: defaults) == nil)
    }
}

struct WeatherSymbolTests {
    @Test func mapsConditionsToSymbols() {
        #expect(weatherSymbol(for: "Sunny") == "sun.max")
        #expect(weatherSymbol(for: "Clear") == "sun.max")
        #expect(weatherSymbol(for: "Light rain") == "cloud.rain")
        #expect(weatherSymbol(for: "Snow showers") == "cloud.snow")   // snow wins over shower
        #expect(weatherSymbol(for: "Partly cloudy") == "cloud.sun")   // "part" wins over "cloud"
        #expect(weatherSymbol(for: "Overcast") == "cloud")
        #expect(weatherSymbol(for: "Thunderstorm") == "cloud.bolt.rain")
        #expect(weatherSymbol(for: "Fog") == "cloud.fog")
        #expect(weatherSymbol(for: "Meteor shower of frogs") == "cloud.rain")  // "shower" → rain
        #expect(weatherSymbol(for: "Whatever") == "cloud")            // default
    }
}

// @spec TRAIL-054
struct ConditionsSummaryTests {
    @Test func sameConditionsShowOnce() {
        let s = conditionsSummary(start: "Sunny", end: "Sunny")
        #expect(s.text == "Sunny")
        #expect(s.symbol == "sun.max")
    }

    @Test func matchIsCaseInsensitiveAndTrimmed() {
        let s = conditionsSummary(start: " Sunny ", end: "sunny")
        #expect(s.text == "Sunny")
    }

    @Test func differingConditionsJoinWithAnArrow() {
        let s = conditionsSummary(start: "Sunny", end: "Thunderstorms")
        #expect(s.text == "Sunny → Thunderstorms")
        #expect(s.symbol == "cloud.bolt.rain")  // the more severe end wins the icon
    }

    @Test func iconPicksTheMoreSevereEndRegardlessOfOrder() {
        #expect(conditionsSummary(start: "Thunderstorms", end: "Sunny").symbol == "cloud.bolt.rain")
        #expect(conditionsSummary(start: "Cloudy", end: "Snow").symbol == "cloud.snow")
    }
}

// @spec TRAIL-059
struct AlertSymbolTests {
    @Test func mapsKnownTypes() {
        #expect(alertSymbol(for: "precip") == "cloud.rain.fill")
        #expect(alertSymbol(for: "heat_index") == "thermometer.sun.fill")
        #expect(alertSymbol(for: "wind_chill") == "thermometer.snowflake")
        #expect(alertSymbol(for: "nws_alert") == "exclamationmark.triangle.fill")
    }

    @Test func fallsBackForAnUnrecognizedType() {
        #expect(alertSymbol(for: "some_future_type") == "exclamationmark.triangle.fill")
    }
}

// @spec TRAIL-053, TRAIL-017, TRAIL-055
struct StatusErrorMappingTests {
    @Test func mapsEachStatusToItsError() {
        #expect(HikeAPI.error(for: 200, badRequestError: .badWindow) == nil)
        #expect(HikeAPI.error(for: 401, badRequestError: .badWindow) == .unauthorized)
        #expect(HikeAPI.error(for: 404, badRequestError: .badWindow) == .notFound)
        #expect(HikeAPI.error(for: 410, badRequestError: .badWindow) == .apiRetired)
        #expect(HikeAPI.error(for: 503, badRequestError: .badWindow) == .server)
    }

    @Test func fourHundredUsesTheCallersMeaning() {
        // /hike/{id}: a 400 means the window was rejected.
        #expect(HikeAPI.error(for: 400, badRequestError: .badWindow) == .badWindow)
        // /hike-locations: no query parameters to reject, so a 400 is a generic server problem.
        #expect(HikeAPI.error(for: 400, badRequestError: .server) == .server)
    }
}

// @spec TRAIL-056, TRAIL-057
struct SunsetTests {
    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SunsetTests-\(UUID().uuidString)")!
    }

    @Test func parsesAnHTTPDateSunsetHeader() {
        let date = HikeAPI.sunsetDate(from: "Wed, 18 Nov 2026 00:00:00 GMT")
        #expect(date != nil)
        #expect(Calendar(identifier: .gregorian).component(.year, from: date!) == 2026)
    }

    @Test func rejectsAGarbledHeader() {
        #expect(HikeAPI.sunsetDate(from: "not a date") == nil)
    }

    @Test func recordsTheSunsetDateFromAResponse() {
        let defaults = isolatedDefaults()
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/hike/x")!, statusCode: 200, httpVersion: nil,
            headerFields: ["Sunset": "Wed, 18 Nov 2026 00:00:00 GMT", "Deprecation": "true"])!
        HikeAPI.recordSunsetIfPresent(from: response, in: defaults)
        #expect(HikeAPI.storedSunsetDate(in: defaults) != nil)
    }

    @Test func clearsAPreviouslyStoredDateWhenTheHeaderIsAbsent() {
        let defaults = isolatedDefaults()
        defaults.set(Date(), forKey: HikeAPI.sunsetKey)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/hike/x")!, statusCode: 200, httpVersion: nil, headerFields: [:])!
        HikeAPI.recordSunsetIfPresent(from: response, in: defaults)
        #expect(HikeAPI.storedSunsetDate(in: defaults) == nil)
    }
}
