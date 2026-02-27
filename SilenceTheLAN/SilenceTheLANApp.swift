import SwiftUI
import SwiftData
import AppIntents

@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register App Shortcuts with Siri
        SilenceTheLANShortcuts.updateAppShortcutParameters()

        // Request notification permission
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Only check when returning from background, not on initial launch
                    // This avoids racing with initial data load
                    if oldPhase == .background && newPhase == .active {
                        Task {
                            await appState.checkExpiredTemporaryAllows()
                        }
                    }
                }
        }
        .modelContainer(SharedModelContainer.container)
    }
}
