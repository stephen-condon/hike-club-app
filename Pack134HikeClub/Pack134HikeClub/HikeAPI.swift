//
//  HikeAPI.swift
//  Pack134HikeClub
//
//  Read-only client for the private Hike Club API (GET /hike/{id}).
//  The app's only network call — owner-triggered, non-authoritative, results ephemeral.
//  Pure decode (HikeResponse + JSONDecoder) is unit-tested; the URLSession call is
//  device/network and not unit-tested (mirrors HealthImport's tested/untested split).
//

import Foundation
import os

// MARK: - Response models (mirror openapi.yaml HikeResponseV3)
// No start/end: v3 never sends them back — the app is the only place a
// hike's date lives, and it already knows the window it asked for.

struct HikeResponse: Codable {
    let id: String
    let meetingPoint: MeetingPoint
    let trails: [String]
    let map: MapRef?
    let mapAvailable: Bool
    let weatherAvailable: Bool
    let weather: Weather?
}

struct MeetingPoint: Codable {
    let lat: Double
    let lon: Double
    let googleMapsUrl: URL
}

struct MapRef: Codable {
    let url: URL
    let expiresAt: Date
}

struct Weather: Codable {
    let startTempF: Double
    let endTempF: Double
    let startConditions: String
    let endConditions: String
    let precipitation: Precipitation
    let heatIndexF: Double?
    let windChillF: Double?
    let alerts: [Alert]
}

struct Precipitation: Codable {
    let probabilityPct: Int
    let expected: Bool
    let startsAt: Date?
    let endsAt: Date?
}

struct Alert: Codable {
    let type: String
    let message: String
}

/// One short-name/full-name mapping from GET /hike-locations (snake_case, unlike the hike payload).
struct HikeLocation: Codable {
    let shortName: String
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case shortName = "short_name"
        case fullName = "full_name"
    }
}

extension HikeLocation {
    static func decode(_ data: Data) throws -> [HikeLocation] {
        try JSONDecoder().decode([HikeLocation].self, from: data)
    }
}

// MARK: - Decoder

extension HikeResponse {
    /// Shared decoder — `date-time` fields are ISO-8601. Separated out so it's unit-testable.
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func decode(_ data: Data) throws -> HikeResponse {
        try decoder.decode(HikeResponse.self, from: data)
    }
}

// MARK: - Errors

enum HikeAPIError: LocalizedError, Equatable {
    case notConfigured
    case badID
    case unauthorized
    case notFound
    case badWindow
    case apiRetired
    case server
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set the API base URL and key in Settings first."
        case .badID:         return "This hike's API ID isn't valid."
        case .unauthorized:  return "API key rejected — check it in Settings."
        case .notFound:      return "No hike with that ID on the server."
        case .badWindow:     return "Check the hike's start and end times."
        case .apiRetired:    return "This app's API version has been retired. Update the app."
        case .server:        return "The trail-info server had a problem. Try again later."
        case .tooLarge:      return "The server response was too large to read."
        }
    }
}

// MARK: - Location list state

// @spec TRAIL-034, TRAIL-047, TRAIL-048, TRAIL-049
/// The cached location list as the owner sees it. The fetch date, not the count,
/// separates "never loaded" from "loaded, and the server has none".
enum LocationListState: Equatable {
    case notFetched
    case empty(fetchedAt: Date)
    case loaded(count: Int, fetchedAt: Date)

    static let emptyNote = "Locations loaded — none are set up yet."

    init(count: Int, fetchedAt: Date?) {
        guard let fetchedAt else { self = .notFetched; return }
        self = count == 0 ? .empty(fetchedAt: fetchedAt) : .loaded(count: count, fetchedAt: fetchedAt)
    }

    var showsEmptyNote: Bool {
        if case .empty = self { return true }
        return false
    }

    /// Clearing forces a refetch, so it is useful whenever anything was fetched.
    var canClear: Bool { self != .notFetched }

    /// Settings → Cached: `none`, or `{count} · {date}` including a count of zero.
    var cacheStatus: String {
        switch self {
        case .notFetched: return "none"
        case .empty(let at): return "0 · \(at.formatted(date: .abbreviated, time: .omitted))"
        case .loaded(let count, let at): return "\(count) · \(at.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

// MARK: - Client

enum HikeAPI {
    static let baseURLKey = "hikeAPIBaseURL"   // UserDefaults (not secret)
    static let apiKeyAccount = "hikeAPIKey"    // Keychain account (secret)
    static let apiVersion = "3"                // x-api-version header → v3 responses
    static let sunsetKey = "hikeAPISunset"     // UserDefaults: stored Sunset header date

    private static let logger = Logger(subsystem: "Pack134HikeClub", category: "HikeAPI")

    /// Parses an HTTP-date (`Sunset` header format, e.g. "Wed, 18 Nov 2026 00:00:00 GMT").
    /// Pure, so it's unit-tested without a network call.
    static func sunsetDate(from header: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f.date(from: header)
    }

    static func storedSunsetDate(in defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: sunsetKey) as? Date
    }

    // @spec TRAIL-056, TRAIL-058
    /// Records or clears the advertised retirement date for the version this app sends,
    /// and logs the deprecation headers once per response — the log is a fallback trail,
    /// not the primary warning (see TRAIL-057's Settings note).
    static func recordSunsetIfPresent(from response: HTTPURLResponse, in defaults: UserDefaults = .standard) {
        guard let sunsetHeader = response.value(forHTTPHeaderField: "Sunset") else {
            defaults.removeObject(forKey: sunsetKey)
            return
        }
        if let date = sunsetDate(from: sunsetHeader) {
            defaults.set(date, forKey: sunsetKey)
        }
        let deprecation = response.value(forHTTPHeaderField: "Deprecation") ?? "—"
        let link = response.value(forHTTPHeaderField: "Link") ?? "—"
        logger.log("""
            API deprecation headers — Deprecation: \(deprecation, privacy: .public), \
            Sunset: \(sunsetHeader, privacy: .public), Link: \(link, privacy: .public)
            """)
    }

    /// Formats the hike window's `start`/`end` query parameters: RFC 3339 with
    /// the device's own offset, since v3 has no other source for the hike's date.
    static let windowFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = .current
        return f
    }()

    /// The `start`/`end` query items `fetch` sends — pure, so the formatting is
    /// unit-tested without a network call.
    static func windowQueryItems(start: Date, end: Date) -> [URLQueryItem] {
        [
            URLQueryItem(name: "start", value: windowFormatter.string(from: start)),
            URLQueryItem(name: "end", value: windowFormatter.string(from: end))
        ]
    }

    // Location-mapping cache (UserDefaults, not secret).
    static let locationsCacheKey = "hikeLocationsCache"
    static let locationsFetchedAtKey = "hikeLocationsFetchedAt"
    static let locationsRefreshInterval: TimeInterval = 7 * 24 * 60 * 60  // refresh target; never a hard expiry

    private static let maxResponseBytes = 5 * 1024 * 1024  // 5 MB sanity cap on a display payload

    /// Base URL (https only) + key, or nil when unconfigured — gates the fetch UI.
    static var config: (baseURL: URL, apiKey: String)? {
        guard let urlString = UserDefaults.standard.string(forKey: baseURLKey),
              let url = URL(string: urlString), url.scheme == "https",
              let key = Keychain.get(apiKeyAccount), !key.isEmpty else { return nil }
        return (url, key)
    }

    // Fetches trail info for `id` over the hike's `[start, end]` window — the
    // only place that window is stored; the API's own record carries no date.
    // @spec TRAIL-010, TRAIL-011, TRAIL-052, TRAIL-053
    static func fetch(id: String, start: Date, end: Date) async throws -> HikeResponse {
        guard let config else { throw HikeAPIError.notConfigured }
        // Reject path-escaping ids (`/`, `..`, query) rather than string-concatenating.
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("?"),
              !trimmed.contains("#") else { throw HikeAPIError.badID }
        // appending(path:) percent-encodes the segment.
        let base = config.baseURL.appending(path: "hike").appending(path: trimmed)
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = windowQueryItems(start: start, end: end)
        guard let url = components?.url else { throw HikeAPIError.badID }
        return try await HikeResponse.decode(getData(from: url, apiKey: config.apiKey, badRequestError: .badWindow))
    }

    static func fetchLocations() async throws -> [HikeLocation] {
        guard let config else { throw HikeAPIError.notConfigured }
        let url = config.baseURL.appending(path: "hike-locations")
        return try await HikeLocation.decode(getData(from: url, apiKey: config.apiKey))
    }

    /// Pure status → error mapping, shared by `getData`. `badRequestError` lets the
    /// caller say what a 400 means on its own endpoint — a bad window on `/hike/{id}`,
    /// a generic server problem on `/hike-locations`, which takes no query parameters
    /// to reject. Returns nil for 200 (no error).
    static func error(for status: Int, badRequestError: HikeAPIError) -> HikeAPIError? {
        switch status {
        case 200: return nil
        case 400: return badRequestError
        case 401: return .unauthorized
        case 404: return .notFound
        case 410: return .apiRetired
        default:  return .server
        }
    }

    /// Shared GET: x-api-key + x-api-version headers, status mapping, and size cap.
    private static func getData(
        from url: URL, apiKey: String, badRequestError: HikeAPIError = .server
    ) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "x-api-version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HikeAPIError.server }
        recordSunsetIfPresent(from: http)
        if let error = error(for: http.statusCode, badRequestError: badRequestError) { throw error }
        guard data.count <= maxResponseBytes else { throw HikeAPIError.tooLarge }
        return data
    }

    // MARK: - Location cache

    static func cachedLocations(in defaults: UserDefaults = .standard) -> [HikeLocation] {
        guard let data = defaults.data(forKey: locationsCacheKey),
              let locations = try? JSONDecoder().decode([HikeLocation].self, from: data) else { return [] }
        return locations
    }

    /// When the list was last fetched successfully — `nil` means never, which is
    /// how an empty cache is told apart from an empty list the server returned.
    static func locationsFetchedAt(in defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: locationsFetchedAtKey) as? Date
    }

    /// Pure staleness rule — testable without touching UserDefaults.
    static func locationsAreStale(fetchedAt: Date?, now: Date) -> Bool {
        guard let fetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) > locationsRefreshInterval
    }

    // @spec TRAIL-046
    static func storeLocations(_ locations: [HikeLocation], in defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        defaults.set(data, forKey: locationsCacheKey)
        defaults.set(Date(), forKey: locationsFetchedAtKey)
    }

    static func clearLocationsCache() {
        UserDefaults.standard.removeObject(forKey: locationsCacheKey)
        UserDefaults.standard.removeObject(forKey: locationsFetchedAtKey)
    }

    /// Refresh when stale; on failure keep the stale cache (only the Settings button clears it).
    static func refreshLocationsIfStale() async {
        guard config != nil, locationsAreStale(fetchedAt: locationsFetchedAt(), now: Date()) else { return }
        if let fresh = try? await fetchLocations() {
            storeLocations(fresh)
        }
    }
}
