import SwiftUI
import SwiftData
import AppIntents

@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppConfiguration.self,
            ACLRule.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
        .modelContainer(sharedModelContainer)
    }
}
