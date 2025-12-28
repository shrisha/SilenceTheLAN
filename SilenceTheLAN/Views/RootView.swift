import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if !appState.isInitialized {
                // Show loading state until configuration is checked
                Color.theme.background
                    .ignoresSafeArea()
            } else if appState.isConfigured {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isConfigured)
        .onAppear {
            if !appState.isInitialized {
                appState.configure(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
        .modelContainer(for: [AppConfiguration.self, ACLRule.self], inMemory: true)
}
