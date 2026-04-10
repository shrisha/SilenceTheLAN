import SwiftUI
import SwiftData

@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    private let marketingScreenshotScenario = MarketingScreenshotScenario.current

    init() {
        if MarketingScreenshotScenario.current == nil {
            // Request notification permission
            Task { @MainActor in
                _ = await NotificationService.shared.requestAuthorization()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let marketingScreenshotScenario {
                    MarketingScreenshotRootView(scenario: marketingScreenshotScenario)
                } else {
                    RootView()
                        .environmentObject(appState)
                        .onChange(of: scenePhase) { oldPhase, newPhase in
                            // Only check when returning from background, not on initial launch
                            // This avoids racing with initial data load
                            if oldPhase == .background && newPhase == .active {
                                Task { @MainActor in
                                    await appState.checkExpiredTemporaryAllows()
                                }
                            }
                        }
                }
            }
                .preferredColorScheme(.dark)
        }
        .modelContainer(AppModelContainer.container)
    }
}
