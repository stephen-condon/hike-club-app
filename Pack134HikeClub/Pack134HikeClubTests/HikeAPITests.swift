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

    // Full v2 payload: weather with start/end temps, a non-expected precip, and an alert.
    static let full = """
    {
      "id": "2026-08-01-ridge-loop",
      "start": "2026-08-01T14:00:00Z",
      "end": "2026-08-01T17:30:00Z",
      "meetingPoint": { "lat": 40.7, "lon": -74.0, "googleMapsUrl": "https://maps.google.com/?q=40.7,-74.0" },
      "trails": ["Ridge Loop", "Creek Spur"],
      "map": { "url": "https://cdn.example.com/map.png", "expiresAt": "2026-08-01T18:00:00Z" },
      "weatherAvailable": true,
      "weather": {
        "startTempF": 62.5,
        "endTempF": 70.0,
        "conditions": "Partly cloudy",
        "precipitation": { "probabilityPct": 20, "expected": false, "startsAt": null, "endsAt": null },
        "heatIndexF": null,
        "windChillF": null,
        "alerts": [ { "type": "heat_index", "message": "Heat advisory" } ]
      }
    }
    """

    // Rainy v2 payload: expected precip with a window + heat index / wind chill present.
    static let rainy = """
    {
      "id": "2026-08-01-creek",
      "start": "2026-08-01T14:00:00Z",
      "end": "2026-08-01T17:00:00Z",
      "meetingPoint": { "lat": 1.0, "lon": 2.0, "googleMapsUrl": "https://maps.google.com/?q=1,2" },
      "trails": ["Creek"],
      "map": { "url": "https://cdn.example.com/m.png", "expiresAt": "2026-08-01T18:00:00Z" },
      "weatherAvailable": true,
      "weather": {
        "startTempF": 55.0,
        "endTempF": 48.0,
        "conditions": "Rain",
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
      "id": "2026-08-02-x",
      "start": "2026-08-02T14:00:00Z",
      "end": "2026-08-02T16:00:00Z",
      "meetingPoint": { "lat": 1.0, "lon": 2.0, "googleMapsUrl": "https://maps.google.com/?q=1,2" },
      "trails": [],
      "map": { "url": "https://cdn.example.com/m.png", "expiresAt": "2026-08-02T17:00:00Z" },
      "weatherAvailable": false,
      "weather": null
    }
    """

    @Test func decodesFullPayload() throws {
        let r = try HikeResponse.decode(Data(Self.full.utf8))
        #expect(r.id == "2026-08-01-ridge-loop")
        #expect(r.trails == ["Ridge Loop", "Creek Spur"])
        #expect(r.meetingPoint.lat == 40.7)
        #expect(r.meetingPoint.googleMapsUrl.scheme == "https")
        #expect(r.map.url.absoluteString == "https://cdn.example.com/map.png")
        #expect(r.weatherAvailable == true)
        #expect(r.weather?.startTempF == 62.5)
        #expect(r.weather?.endTempF == 70.0)
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
        let expected = ISO8601DateFormatter().date(from: "2026-08-01T14:00:00Z")
        #expect(r.start == expected)
        #expect(r.end > r.start)
    }

    @Test func decodesNullWeather() throws {
        let r = try HikeResponse.decode(Data(Self.noWeather.utf8))
        #expect(r.weatherAvailable == false)
        #expect(r.weather == nil)
        #expect(r.trails.isEmpty)
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: (any Error).self) {
            try HikeResponse.decode(Data("{ not json".utf8))
        }
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

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func makesKnownIDs() {
        #expect(HikeID.make(date: date(2026, 7, 25), slug: "danada-equestrian-center")
                == "2026-07-25-danada-equestrian-center")
        #expect(HikeID.make(date: date(2026, 8, 29), slug: "cantigny-park")
                == "2026-08-29-cantigny-park")
        #expect(HikeID.make(date: date(2026, 9, 19), slug: "mallard-lake-forest-preserve")
                == "2026-09-19-mallard-lake-forest-preserve")
    }

    @Test func extractsSlugFromID() {
        #expect(HikeID.slug(from: "2026-07-25-danada-equestrian-center") == "danada-equestrian-center")
        #expect(HikeID.slug(from: "2026-09-19-mallard-lake-forest-preserve") == "mallard-lake-forest-preserve")
    }

    @Test func rejectsNonConformingID() {
        #expect(HikeID.slug(from: "cantigny-park") == nil)   // no date prefix
        #expect(HikeID.slug(from: "") == nil)
        #expect(HikeID.slug(from: "2026-07-25-") == nil)     // empty slug
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
