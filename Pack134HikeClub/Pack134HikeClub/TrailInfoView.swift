//
//  TrailInfoView.swift
//  Pack134HikeClub
//
//  Read-only Trail Info section for a hike linked to the Hike Club API.
//  Owns its own fetch state; results are ephemeral (never persisted).
//  Remote strings render as Text(variable) and response URLs are https-gated before
//  AsyncImage/Link — no markdown/deep-link injection from the untrusted response.
//

import SwiftUI
import UIKit

struct TrailInfoView: View {
    let apiHikeID: String
    // The hike's window — the only source of its date under API v3; the
    // server's record carries none.
    let start: Date
    let end: Date

    @State private var info: HikeResponse?
    @State private var isFetching = false
    @State private var message: String?
    @State private var showMap = false
    // Loaded once per fetch and shared with the zoom view, so zooming never re-hits
    // the (signed, expiring) map URL. Replaced/cleared on every refetch.
    @State private var mapImage: UIImage?
    @State private var mapFailed = false

    var body: some View {
        Section("Trail Info") {
            if HikeAPI.config == nil {
                Text("Set the API base URL and key in Settings to load trail info.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                fetchButton
            }
            if let info { details(info) }
        }
        .alert("Trail Info", isPresented: Binding(get: { message != nil },
                                                  set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var fetchButton: some View {
        Button {
            Task { await fetch() }
        } label: {
            if isFetching {
                ProgressView()
            } else {
                Label(info == nil ? "Fetch trail info" : "Refresh trail info", systemImage: "map")
            }
        }
        .disabled(isFetching)
    }

    // @spec TRAIL-051
    @ViewBuilder
    private func details(_ info: HikeResponse) -> some View {
        // Map image — only rendered for an https URL (untrusted host from the response);
        // loaded once in loadMap() and shared with the zoom view. A hike whose map
        // image never uploaded serves with no map at all under v3, distinct from a
        // present-but-unloadable one.
        if let map = info.map, map.url.scheme == "https" {
            if let mapImage {
                Image(uiImage: mapImage).resizable().scaledToFit()
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .padding(6)
                            .background(.thinMaterial, in: Circle())
                            .padding(6)
                    }
                    .onTapGesture { showMap = true }
                    .fullScreenCover(isPresented: $showMap) {
                        ZoomableImageView(image: mapImage)
                    }
            } else if mapFailed {
                Label("Map unavailable", systemImage: "map").foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        } else if info.map != nil {
            // Present but not https — same "unavailable" the app already used to
            // refuse an untrusted-scheme URL.
            Label("Map unavailable", systemImage: "map").foregroundStyle(.secondary)
        } else {
            Label("No map for this trail", systemImage: "map").foregroundStyle(.secondary)
        }

        // Meeting point — coords + Google Maps link (https only)
        LabeledContent("Meeting point",
                       value: String(format: "%.4f, %.4f", info.meetingPoint.lat, info.meetingPoint.lon))
        if info.meetingPoint.googleMapsUrl.scheme == "https" {
            Link("Open in Maps", destination: info.meetingPoint.googleMapsUrl)
        }

        // Trails — remote strings as plain Text (no markdown/link parsing)
        ForEach(info.trails, id: \.self) { trail in
            LabeledContent("Trail", value: trail)
        }

        weatherRows(info)
    }

    // @spec TRAIL-054
    @ViewBuilder
    private func weatherRows(_ info: HikeResponse) -> some View {
        if info.weatherAvailable, let weather = info.weather {
            Label(weather.startConditions, systemImage: weatherSymbol(for: weather.startConditions))
            LabeledContent("Start temp", value: tempString(weather.startTempF))
            LabeledContent("End temp", value: tempString(weather.endTempF))
            LabeledContent("End conditions", value: weather.endConditions)
            if let heat = weather.heatIndexF {
                LabeledContent("Heat index", value: tempString(heat))
            }
            if let chill = weather.windChillF {
                LabeledContent("Wind chill", value: tempString(chill))
            }
            LabeledContent("Precipitation", value: precipString(weather.precipitation))
            ForEach(Array(weather.alerts.enumerated()), id: \.offset) { _, alert in
                Label(alert.message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        } else {
            Text("Weather unavailable").foregroundStyle(.secondary)
        }
    }

    private func tempString(_ fahrenheit: Double) -> String {
        "\(fahrenheit.formatted(.number.precision(.fractionLength(0))))°F"
    }

    private func precipString(_ p: Precipitation) -> String {
        var s = "\(p.probabilityPct)% (\(p.expected ? "expected" : "not expected"))"
        if let start = p.startsAt, let end = p.endsAt {
            let f = Date.FormatStyle(date: .omitted, time: .shortened)
            s += ", \(start.formatted(f))–\(end.formatted(f))"
        }
        return s
    }

    private func fetch() async {
        isFetching = true
        defer { isFetching = false }
        do {
            let response = try await HikeAPI.fetch(id: apiHikeID, start: start, end: end)
            info = response
            if let map = response.map {
                await loadMap(map.url)
            } else {
                mapImage = nil
                mapFailed = false
            }
        } catch {
            message = error.localizedDescription
        }
    }

    // Fetch the (signed, expiring) map URL exactly once per refetch. mapImage is the
    // "local cache"; clearing it here is the cache-clear-on-refetch. Device-only network
    // glue, untested like the other HikeAPI/HealthImport calls.
    private func loadMap(_ url: URL) async {
        mapImage = nil
        mapFailed = false
        // Only fetch an https URL (untrusted host from the API response).
        guard url.scheme == "https" else { mapFailed = true; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) { mapImage = img } else { mapFailed = true }
        } catch {
            mapFailed = true
        }
    }
}
