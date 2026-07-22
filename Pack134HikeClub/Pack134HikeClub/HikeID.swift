//
//  HikeID.swift
//  Pack134HikeClub
//
//  A hike's API id is derived from its date + the picked location's short_name slug:
//  "yyyy-MM-dd-<slug>" (e.g. 2026-07-25-danada-equestrian-center). Pure + unit-tested.
//

import Foundation

enum HikeID {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Build the API id for a hike on `date` at the location `slug`.
    static func make(date: Date, slug: String) -> String {
        "\(dateFormatter.string(from: date))-\(slug)"
    }

    /// The location slug embedded in an id, or nil if the id lacks a leading `yyyy-MM-dd-`.
    static func slug(from id: String) -> String? {
        guard id.count > 11 else { return nil }
        let p = Array(id.prefix(11))  // "yyyy-MM-dd-"
        let looksLikeDate = p[0...3].allSatisfy(\.isNumber) && p[4] == "-"
            && p[5...6].allSatisfy(\.isNumber) && p[7] == "-"
            && p[8...9].allSatisfy(\.isNumber) && p[10] == "-"
        guard looksLikeDate else { return nil }
        return String(id.dropFirst(11))
    }
}

// SF Symbol for a free-form weather `conditions` string.
// ponytail: keyword heuristic over an unconstrained string; swap for a `switch` if the API ever
// pins conditions to an enum.
func weatherSymbol(for conditions: String) -> String {
    let c = conditions.lowercased()
    if c.contains("snow") { return "cloud.snow" }
    if c.contains("thunder") || c.contains("storm") { return "cloud.bolt.rain" }
    if c.contains("rain") || c.contains("shower") || c.contains("drizzle") { return "cloud.rain" }
    if c.contains("fog") || c.contains("mist") || c.contains("haze") { return "cloud.fog" }
    if c.contains("part") { return "cloud.sun" }
    if c.contains("cloud") || c.contains("overcast") { return "cloud" }
    if c.contains("clear") || c.contains("sun") { return "sun.max" }
    return "cloud"
}
