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

struct TrailInfoView: View {
    let apiHikeID: String

    @State private var info: HikeResponse?
    @State private var isFetching = false
    @State private var message: String?

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

    @ViewBuilder
    private func details(_ info: HikeResponse) -> some View {
        // Map image — only render an https URL (untrusted host from the response).
        if info.map.url.scheme == "https" {
            AsyncImage(url: info.map.url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Label("Map unavailable", systemImage: "map").foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
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

    @ViewBuilder
    private func weatherRows(_ info: HikeResponse) -> some View {
        if info.weatherAvailable, let weather = info.weather {
            Label(weather.conditions, systemImage: weatherSymbol(for: weather.conditions))
            LabeledContent("Start temp", value: tempString(weather.startTempF))
            LabeledContent("End temp", value: tempString(weather.endTempF))
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
            info = try await HikeAPI.fetch(id: apiHikeID)
        } catch {
            message = error.localizedDescription
        }
    }
}
