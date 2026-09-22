//
//  HikeID.swift
//  Pack134HikeClub
//
//  A hike's API id is the picked location's short_name slug, with no date
//  (e.g. danada-equestrian-center) — the API keeps one record per location and
//  updates it in place, so the id is stable across reschedules.
//
//  Ids used to be "yyyy-MM-dd-<slug>", and hikes saved before that change still
//  hold the dated form in SwiftData. `normalize` strips the legacy prefix on read,
//  so no store migration is needed. Pure + unit-tested.
//

import Foundation

enum HikeID {
    /// The bare location slug for `id`: strips a legacy `yyyy-MM-dd-` prefix if one
    /// is present, otherwise returns `id` unchanged.
    static func normalize(_ id: String) -> String {
        guard id.count > 11 else { return id }
        let p = Array(id.prefix(11))  // "yyyy-MM-dd-"
        let looksLikeDate = p[0...3].allSatisfy(\.isNumber) && p[4] == "-"
            && p[5...6].allSatisfy(\.isNumber) && p[7] == "-"
            && p[8...9].allSatisfy(\.isNumber) && p[10] == "-"
        guard looksLikeDate else { return id }
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

// Symbol severity, most severe first — decides which of a start/end conditions
// pair's icons wins in `conditionsSummary`.
private let conditionsSeverity = [
    "cloud.bolt.rain", "cloud.snow", "cloud.rain", "cloud.fog", "cloud", "cloud.sun", "sun.max"
]

// @spec TRAIL-054
/// Combines a hike's start/end conditions into one phrase and icon: the shared phrase
/// when they match (case-insensitive), otherwise both joined by an arrow; the icon is
/// whichever end's `weatherSymbol` ranks more severe. Pure + unit-tested.
func conditionsSummary(start: String, end: String) -> (text: String, symbol: String) {
    let start = start.trimmingCharacters(in: .whitespaces)
    let end = end.trimmingCharacters(in: .whitespaces)
    let text = start.caseInsensitiveCompare(end) == .orderedSame ? start : "\(start) → \(end)"
    let startSymbol = weatherSymbol(for: start)
    let endSymbol = weatherSymbol(for: end)
    func rank(_ symbol: String) -> Int { conditionsSeverity.firstIndex(of: symbol) ?? conditionsSeverity.count }
    let symbol = rank(startSymbol) <= rank(endSymbol) ? startSymbol : endSymbol
    return (text, symbol)
}

// @spec TRAIL-059
/// SF Symbol for an alert's `type` (`precip`/`heat_index`/`wind_chill`/`nws_alert`),
/// falling back to the shared warning triangle for `nws_alert` and any type the app
/// doesn't recognize (the server can add alert types the app hasn't seen yet).
func alertSymbol(for type: String) -> String {
    switch type {
    case "precip":      return "cloud.rain.fill"
    case "heat_index":  return "thermometer.sun.fill"
    case "wind_chill":  return "thermometer.snowflake"
    default:            return "exclamationmark.triangle.fill"
    }
}
