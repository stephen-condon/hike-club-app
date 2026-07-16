//
//  SettingsView.swift
//  Pack134HikeClub
//
//  Configures the Hike Club API: base URL (UserDefaults, not secret) and API key
//  (Keychain, secret). The key is entered here once per device and never read back into
//  the field — only a masked "set" state is shown.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(HikeAPI.baseURLKey) private var baseURL: String = ""
    @State private var keyEntry: String = ""
    @State private var keyIsSet: Bool = Keychain.get(HikeAPI.apiKeyAccount) != nil
    @State private var message: String?

    // https-only: prevents ever sending the API key to an http/wrong host.
    private var baseURLIsValid: Bool {
        baseURL.isEmpty || URL(string: baseURL)?.scheme == "https"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hike Club API") {
                    TextField("Base URL (https://…)", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    if !baseURLIsValid {
                        Text("Base URL must start with https://")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("API Key") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(keyIsSet ? "•••• set" : "not set")
                            .foregroundStyle(keyIsSet ? .green : .secondary)
                    }
                    SecureField("Paste API key", text: $keyEntry)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save key") {
                        Keychain.set(keyEntry, for: HikeAPI.apiKeyAccount)
                        keyEntry = ""
                        keyIsSet = true
                        message = "API key saved to Keychain."
                    }
                    .disabled(keyEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                    if keyIsSet {
                        Button("Clear key", role: .destructive) {
                            Keychain.delete(HikeAPI.apiKeyAccount)
                            keyIsSet = false
                            message = "API key removed."
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Settings", isPresented: Binding(get: { message != nil },
                                                    set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }
}
