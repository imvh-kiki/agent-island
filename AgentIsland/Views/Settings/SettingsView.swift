import SwiftUI

struct SettingsView: View {
    @AppStorage("autoStart") private var autoStart = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $autoStart)
                Toggle("Show in menu bar", isOn: $showInMenuBar)
            }

            Section("About") {
                HStack {
                    Text("Agent Island")
                        .font(.headline)
                    Spacer()
                    Text("v0.1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 200)
    }
}
