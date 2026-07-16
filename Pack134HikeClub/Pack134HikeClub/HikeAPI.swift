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

// MARK: - Response models (mirror openapi.yaml HikeResponse)

struct HikeResponse: Codable {
    let id: String
    let start: Date
    let end: Date
    let meetingPoint: MeetingPoint
    let trails: [String]
    let map: MapRef
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
    let temperatureF: Double
    let conditions: String
    let precipitation: Precipitation
    let heatIndexF: Double?
    let windChillF: Double?
    let alerts: [Alert]
}

struct Precipitation: Codable {
    let probabilityPct: Int
    let amountIn: Double
}

struct Alert: Codable {
    let type: String
    let message: String
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

enum HikeAPIError: LocalizedError {
    case notConfigured
    case badID
    case unauthorized
    case notFound
    case server
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set the API base URL and key in Settings first."
        case .badID:         return "This hike's API ID isn't valid."
        case .unauthorized:  return "API key rejected — check it in Settings."
        case .notFound:      return "No hike with that ID on the server."
        case .server:        return "The trail-info server had a problem. Try again later."
        case .tooLarge:      return "The server response was too large to read."
        }
    }
}

// MARK: - Client

enum HikeAPI {
    static let baseURLKey = "hikeAPIBaseURL"   // UserDefaults (not secret)
    static let apiKeyAccount = "hikeAPIKey"    // Keychain account (secret)

    private static let maxResponseBytes = 5 * 1024 * 1024  // 5 MB sanity cap on a display payload

    /// Base URL (https only) + key, or nil when unconfigured — gates the fetch UI.
    static var config: (baseURL: URL, apiKey: String)? {
        guard let urlString = UserDefaults.standard.string(forKey: baseURLKey),
              let url = URL(string: urlString), url.scheme == "https",
              let key = Keychain.get(apiKeyAccount), !key.isEmpty else { return nil }
        return (url, key)
    }

    static func fetch(id: String) async throws -> HikeResponse {
        guard let config else { throw HikeAPIError.notConfigured }
        // Reject path-escaping ids (`/`, `..`, query) rather than string-concatenating.
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("?"),
              !trimmed.contains("#") else { throw HikeAPIError.badID }
        // appending(path:) percent-encodes the segment.
        let url = config.baseURL.appending(path: "hike").appending(path: trimmed)

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HikeAPIError.server }
        switch http.statusCode {
        case 200:               break
        case 401:               throw HikeAPIError.unauthorized
        case 404:               throw HikeAPIError.notFound
        default:                throw HikeAPIError.server
        }
        guard data.count <= maxResponseBytes else { throw HikeAPIError.tooLarge }
        return try HikeResponse.decode(data)
    }
}
