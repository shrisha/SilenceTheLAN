import SwiftUI

enum MarketingScreenshotScenario: String, CaseIterable {
    case welcome
    case discovery
    case login
    case dashboard
    case timeExtension = "extension"
    case settings

    static var current: MarketingScreenshotScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-marketing-screenshot"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }

        return MarketingScreenshotScenario(rawValue: arguments[flagIndex + 1])
    }
}

struct MarketingScreenshotRootView: View {
    let scenario: MarketingScreenshotScenario
    @StateObject private var appState: AppState

    @MainActor
    init(scenario: MarketingScreenshotScenario) {
        self.scenario = scenario
        _appState = StateObject(wrappedValue: MarketingPreviewFactory.makeAppState(for: scenario))
    }

    var body: some View {
        Group {
            switch scenario {
            case .welcome:
                MarketingOnboardingFrame(step: .welcome) {
                    WelcomeStep(viewModel: MarketingPreviewFactory.makeSetupViewModel(for: .welcome))
                }
            case .discovery:
                MarketingOnboardingFrame(step: .discovery) {
                    HostDiscoveryStep(
                        viewModel: MarketingPreviewFactory.makeSetupViewModel(for: .discovery),
                        allowsAutoDiscovery: false
                    )
                }
            case .login:
                MarketingOnboardingFrame(step: .credentials) {
                    CredentialsStep(viewModel: MarketingPreviewFactory.makeSetupViewModel(for: .login))
                }
            case .dashboard:
                DashboardView(allowsAutoRefresh: false)
                    .environmentObject(appState)
            case .timeExtension:
                DashboardView(allowsAutoRefresh: false)
                    .environmentObject(appState)
            case .settings:
                SettingsView(showsDoneButton: false, previewUsername: "shrisha")
                    .environmentObject(appState)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private enum MarketingOnboardingStep {
    case welcome
    case discovery
    case credentials

    var index: Int {
        switch self {
        case .welcome: 0
        case .discovery: 1
        case .credentials: 2
        }
    }
}

private struct MarketingOnboardingFrame<Content: View>: View {
    let step: MarketingOnboardingStep
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            backgroundEffects

            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, 20)

                content
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index <= step.index ? Color.theme.success : Color.theme.textTertiary)
                    .frame(width: index == step.index ? 32 : 8, height: 8)
            }
        }
        .padding(.horizontal, 40)
    }

    private var backgroundEffects: some View {
        ZStack {
            Circle()
                .fill(Color.theme.success.opacity(0.08))
                .frame(width: 300, height: 300)
                .offset(x: 150, y: -200)
                .blur(radius: 40)

            Circle()
                .fill(Color.theme.accent.opacity(0.05))
                .frame(width: 300, height: 300)
                .offset(x: -150, y: 300)
                .blur(radius: 40)
        }
        .drawingGroup()
    }
}

@MainActor
private enum MarketingPreviewFactory {
    static func makeSetupViewModel(for scenario: MarketingScreenshotScenario) -> SetupViewModel {
        let viewModel = SetupViewModel()
        viewModel.host = "192.168.1.1"
        viewModel.username = "shrisha"
        viewModel.password = "password"

        switch scenario {
        case .welcome:
            viewModel.currentStep = .welcome
        case .discovery:
            viewModel.currentStep = .discovery
            viewModel.discoveredHost = "192.168.1.1"
            viewModel.isLoading = false
        case .login:
            viewModel.currentStep = .credentials
        case .dashboard, .timeExtension, .settings:
            break
        }

        return viewModel
    }

    static func makeAppState(for scenario: MarketingScreenshotScenario) -> AppState {
        let appState = AppState()
        appState.isInitialized = true
        appState.isConfigured = true
        appState.isLoading = false
        appState.errorMessage = nil
        appState.rules = sampleRules(for: scenario)
        appState.networkMonitor.configure(host: "192.168.1.1")
        return appState
    }

    static func sampleRules(for scenario: MarketingScreenshotScenario) -> [ACLRule] {
        let now = Date()

        let rishiGames = makeRule(
            id: "rishi-games",
            name: "STL-Rishi-Games",
            activity: "Games",
            isBlocking: false,
            schedule: ("8:00", "9:00")
        )
        let rishiInternet = makeRule(
            id: "rishi-internet",
            name: "STL-Rishi",
            activity: "Internet",
            isBlocking: true,
            schedule: ("9:00", "10:00")
        )
        let rohanGames = makeRule(
            id: "rohan-games",
            name: "STL-Rohan-Games",
            activity: "Games",
            isBlocking: false,
            schedule: ("8:00", "9:00")
        )
        let rohanInternet = makeRule(
            id: "rohan-internet",
            name: "STL-Rohan",
            activity: "Internet",
            isBlocking: true,
            schedule: ("9:00", "10:00")
        )
        let srTestYouTube = makeRule(
            id: "srtest-youtube",
            name: "STL-SRTest-YouTube",
            activity: "YouTube",
            isBlocking: false,
            schedule: ("8:00", "9:00")
        )
        let srTestYahoo = makeRule(
            id: "srtest-yahoo",
            name: "STL-SRTest-Yahoo",
            activity: "Yahoo",
            isBlocking: false,
            schedule: ("8:00", "9:00")
        )

        if scenario == .timeExtension {
            rishiInternet.temporaryAllowExpiry = now.addingTimeInterval(30 * 60)
            rishiInternet.temporaryAllowOriginalEnabled = true
            rishiInternet.originalScheduleStart = "9:00"
            rishiInternet.originalScheduleEnd = "10:00"
            rishiInternet.scheduleMode = "ALWAYS"
            rishiInternet.action = "BLOCK"
            rishiInternet.isEnabled = false
        }

        return [rishiInternet, rishiGames, rohanInternet, rohanGames, srTestYouTube, srTestYahoo]
    }

    private static func makeRule(
        id: String,
        name: String,
        activity: String,
        isBlocking: Bool,
        schedule: (String, String)
    ) -> ACLRule {
        let rule = ACLRule(
            ruleId: id,
            name: activity == "Internet" ? name : "\(name)",
            action: "BLOCK",
            index: 0,
            isEnabled: isBlocking,
            scheduleMode: isBlocking ? "ALWAYS" : "CUSTOM",
            scheduleStart: schedule.0,
            scheduleEnd: schedule.1,
            isSelected: true
        )
        if isBlocking {
            rule.originalScheduleStart = schedule.0
            rule.originalScheduleEnd = schedule.1
        }
        return rule
    }
}

#Preview("Dashboard") {
    MarketingScreenshotRootView(scenario: .dashboard)
}
