import SwiftUI

@main
struct AgentIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — the app runs as a menu bar + floating panel app
        Settings {
            SettingsView()
        }
    }
}
