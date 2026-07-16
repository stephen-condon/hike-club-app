//
//  HikeAPITests.swift
//  Pack134HikeClubTests
//
//  Decode-side tests for the Hike Club API response. The URLSession call is device-only
//  and not unit-tested (mirrors HealthImportTests covering only the pure conversions).
//

import Testing
import Foundation
@testable import Pack134HikeClub

struct HikeResponseDecodeTests {

    // Full payload with weather + an alert.
    static let full = """
    {
      "id": "hike-42",
      "start": "2026-08-01T14:00:00Z",
      "end": "2026-08-01T17:30:00Z",
      "meetingPoint": { "lat": 40.7, "lon": -74.0, "googleMapsUrl": "https://maps.google.com/?q=40.7,-74.0" },
      "trails": ["Ridge Loop", "Creek Spur"],
      "map": { "url": "https://cdn.example.com/map.png", "expiresAt": "2026-08-01T18:00:00Z" },
      "weatherAvailable": true,
      "weather": {
        "temperatureF": 62.5,
        "conditions": "Partly cloudy",
        "precipitation": { "probabilityPct": 20, "amountIn": 0.1 },
        "heatIndexF": null,
        "windChillF": null,
        "alerts": [ { "type": "heat_index", "message": "Heat advisory" } ]
      }
    }
    """

    // weatherAvailable false, weather null (the nullable path).
    static let noWeather = """
    {
      "id": "hike-7",
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
        #expect(r.id == "hike-42")
        #expect(r.trails == ["Ridge Loop", "Creek Spur"])
        #expect(r.meetingPoint.lat == 40.7)
        #expect(r.meetingPoint.googleMapsUrl.scheme == "https")
        #expect(r.map.url.absoluteString == "https://cdn.example.com/map.png")
        #expect(r.weatherAvailable == true)
        #expect(r.weather?.temperatureF == 62.5)
        #expect(r.weather?.precipitation.probabilityPct == 20)
        #expect(r.weather?.heatIndexF == nil)
        #expect(r.weather?.alerts.first?.message == "Heat advisory")
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
