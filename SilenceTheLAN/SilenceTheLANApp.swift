import SwiftUI
import SwiftData

@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
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
        .modelContainer(for: [AppConfiguration.self, ACLRule.self])
    }
}
