import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SetupViewModel()
    @State private var slideOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background
            Color.theme.background
                .ignoresSafeArea()

            // Ambient glow effects
            backgroundEffects

            // Content
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, 20)

                // Step content
                TabView(selection: $viewModel.currentStep) {
                    WelcomeStep(viewModel: viewModel)
                        .tag(SetupViewModel.SetupStep.welcome)

                    HostDiscoveryStep(viewModel: viewModel)
                        .tag(SetupViewModel.SetupStep.discovery)

                    APIKeyStep(viewModel: viewModel)
                        .tag(SetupViewModel.SetupStep.apiKey)

                    SiteIdStep(viewModel: viewModel)
                        .tag(SetupViewModel.SetupStep.siteId)

                    RuleSelectionStep(viewModel: viewModel, appState: appState)
                        .tag(SetupViewModel.SetupStep.ruleSelection)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentStep)
            }
        }
    }

    // MARK: - Background Effects

    private var backgroundEffects: some View {
        ZStack {
            // Top-right glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.theme.neonGreen.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 150, y: -200)
                .blur(radius: 60)

            // Bottom-left glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.theme.neonPurple.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -150, y: 300)
                .blur(radius: 60)
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(SetupViewModel.SetupStep.allCases.enumerated()), id: \.element) { index, step in
                if step != .complete {
                    Capsule()
                        .fill(stepColor(for: step))
                        .frame(width: isCurrentStep(step) ? 32 : 8, height: 8)
                        .animation(.spring(response: 0.4), value: viewModel.currentStep)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func stepColor(for step: SetupViewModel.SetupStep) -> Color {
        let steps = SetupViewModel.SetupStep.allCases
        guard let currentIndex = steps.firstIndex(of: viewModel.currentStep),
              let stepIndex = steps.firstIndex(of: step) else {
            return Color.theme.textTertiary
        }

        if stepIndex < currentIndex {
            return Color.theme.neonGreen
        } else if stepIndex == currentIndex {
            return Color.theme.neonGreen
        } else {
            return Color.theme.textTertiary
        }
    }

    private func isCurrentStep(_ step: SetupViewModel.SetupStep) -> Bool {
        step == viewModel.currentStep
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo / Icon
            ZStack {
                // Outer glow rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.theme.neonGreen.opacity(0.1 - Double(i) * 0.03), lineWidth: 2)
                        .frame(width: 160 + CGFloat(i) * 40)
                }

                // Main icon
                Image(systemName: "wifi.slash")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.theme.neonGreen, Color.theme.neonBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .neonGlow(Color.theme.neonGreen, radius: 20)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            // Text content
            VStack(spacing: 16) {
                Text("SilenceTheLAN")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.theme.textSecondary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Control your kids' internet\nwith a tap")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(Color.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(textOpacity)

            Spacer()

            // Get Started button
            Button {
                viewModel.nextStep()
            } label: {
                HStack(spacing: 12) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(.neon(Color.theme.neonGreen))
            .opacity(buttonOpacity)

            Spacer()
                .frame(height: 60)
        }
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                buttonOpacity = 1.0
            }
        }
    }
}

// MARK: - Host Discovery Step

struct HostDiscoveryStep: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var isManualEntry = false
    @FocusState private var isHostFieldFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("Find Your UniFi")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Scanning your network for UniFi controller")
                    .font(.subheadline)
                    .foregroundColor(Color.theme.textSecondary)
            }

            // Scanning animation or result
            if viewModel.isLoading {
                RadarScanView()
                    .frame(height: 250)
            } else if let host = viewModel.discoveredHost {
                // Found!
                discoveredHostCard(host: host)
            } else if isManualEntry {
                // Manual entry
                manualEntryCard
            } else {
                // Not found - show options
                notFoundView
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 16) {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.ghost(Color.theme.textSecondary))

                if viewModel.discoveredHost != nil || (isManualEntry && !viewModel.host.isEmpty) {
                    Button("Continue") {
                        viewModel.nextStep()
                    }
                    .buttonStyle(.neon(Color.theme.neonGreen))
                }
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 32)
        .onAppear {
            Task {
                await viewModel.discoverUniFi()
            }
        }
    }

    private func discoveredHostCard(host: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(Color.theme.neonGreen)
                .neonGlow(Color.theme.neonGreen, radius: 15)

            Text("Found UniFi Controller")
                .font(.headline)
                .foregroundColor(.white)

            Text(host)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Color.theme.neonGreen)
        }
        .padding(32)
        .glassCard()
    }

    private var manualEntryCard: some View {
        VStack(spacing: 20) {
            Text("Enter Controller IP")
                .font(.headline)
                .foregroundColor(.white)

            TextField("192.168.1.1", text: $viewModel.host)
                .textFieldStyle(NeonTextFieldStyle())
                .keyboardType(.decimalPad)
                .focused($isHostFieldFocused)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Color.theme.neonRed)
            }
        }
        .padding(24)
        .glassCard()
    }

    private var notFoundView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color.theme.textSecondary)

            Text("No UniFi controller found")
                .font(.headline)
                .foregroundColor(.white)

            Button("Enter Manually") {
                withAnimation(.spring(response: 0.4)) {
                    isManualEntry = true
                }
            }
            .buttonStyle(.ghost(Color.theme.neonGreen))

            Button("Try Again") {
                Task {
                    await viewModel.discoverUniFi()
                }
            }
            .buttonStyle(.ghost(Color.theme.textSecondary))
        }
        .padding(32)
        .glassCard()
    }
}

// MARK: - API Key Step

struct APIKeyStep: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var showInstructions = false
    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.theme.neonGreen, Color.theme.neonBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .neonGlow(Color.theme.neonGreen, radius: 10)

                    Text("API Key")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Enter your UniFi API key")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.textSecondary)
                }

                // API Key input
                VStack(spacing: 16) {
                    SecureField("Paste your API key", text: $viewModel.apiKey)
                        .textFieldStyle(NeonTextFieldStyle())
                        .focused($isKeyFieldFocused)

                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.caption)
                        .foregroundColor(Color.theme.neonRed)
                    }
                }
                .padding(24)
                .glassCard()

                // Instructions toggle
                VStack(spacing: 16) {
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            showInstructions.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("How to get an API key")
                            Spacer()
                            Image(systemName: showInstructions ? "chevron.up" : "chevron.down")
                        }
                        .font(.subheadline)
                        .foregroundColor(Color.theme.neonBlue)
                    }

                    if showInstructions {
                        VStack(alignment: .leading, spacing: 12) {
                            instructionStep(1, "Open your UniFi Console")
                            instructionStep(2, "Go to Settings → Integrations")
                            instructionStep(3, "Click \"Create New API Key\"")
                            instructionStep(4, "Copy the key and paste it above")
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(20)
                .glassCard()

                Spacer()

                // Navigation
                HStack(spacing: 16) {
                    Button("Back") {
                        viewModel.previousStep()
                    }
                    .buttonStyle(.ghost(Color.theme.textSecondary))

                    Button {
                        Task {
                            if await viewModel.verifyAPIKey() {
                                viewModel.nextStep()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Verify")
                        }
                    }
                    .buttonStyle(.neon(Color.theme.neonGreen))
                    .disabled(viewModel.apiKey.isEmpty || viewModel.isLoading)
                    .opacity(viewModel.apiKey.isEmpty ? 0.5 : 1)
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.theme.neonGreen))

            Text(text)
                .font(.subheadline)
                .foregroundColor(Color.theme.textSecondary)
        }
    }
}

// MARK: - Site ID Step

struct SiteIdStep: View {
    @ObservedObject var viewModel: SetupViewModel
    @FocusState private var isSiteIdFieldFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.theme.neonPurple, Color.theme.neonBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .neonGlow(Color.theme.neonPurple, radius: 10)

                Text("Site ID")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Enter your UniFi Site UUID")
                    .font(.subheadline)
                    .foregroundColor(Color.theme.textSecondary)
            }

            // Site ID input
            VStack(spacing: 16) {
                TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $viewModel.siteId)
                    .textFieldStyle(NeonTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isSiteIdFieldFocused)

                Text("Find this in your UniFi Console URL after /site/")
                    .font(.caption)
                    .foregroundColor(Color.theme.textTertiary)
                    .multilineTextAlignment(.center)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color.theme.neonRed)
                }
            }
            .padding(24)
            .glassCard()

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.ghost(Color.theme.textSecondary))

                Button("Continue") {
                    viewModel.nextStep()
                    Task {
                        await viewModel.loadRules()
                    }
                }
                .buttonStyle(.neon(Color.theme.neonGreen))
                .disabled(viewModel.siteId.isEmpty)
                .opacity(viewModel.siteId.isEmpty ? 0.5 : 1)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Rule Selection Step

struct RuleSelectionStep: View {
    @ObservedObject var viewModel: SetupViewModel
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Select Rules")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Choose which rules to manage")
                    .font(.subheadline)
                    .foregroundColor(Color.theme.textSecondary)
            }
            .padding(.top, 20)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.neonGreen))
                    .scaleEffect(1.5)
                Text("Loading rules...")
                    .font(.subheadline)
                    .foregroundColor(Color.theme.textSecondary)
                Spacer()
            } else if viewModel.availableRules.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                // Select all button
                HStack {
                    Button {
                        if viewModel.selectedRuleIds.count == viewModel.availableRules.count {
                            viewModel.deselectAllRules()
                        } else {
                            viewModel.selectAllRules()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.selectedRuleIds.count == viewModel.availableRules.count ? "checkmark.square.fill" : "square")
                            Text("Select All")
                        }
                        .font(.subheadline)
                        .foregroundColor(Color.theme.neonGreen)
                    }
                    Spacer()
                    Text("\(viewModel.selectedRuleIds.count) selected")
                        .font(.caption)
                        .foregroundColor(Color.theme.textSecondary)
                }
                .padding(.horizontal, 8)

                // Rules list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.availableRules, id: \.id) { rule in
                            RuleSelectionCard(
                                rule: rule,
                                isSelected: viewModel.selectedRuleIds.contains(rule.id),
                                onTap: { viewModel.toggleRuleSelection(rule.id) }
                            )
                        }
                    }
                    .padding(.bottom, 100)
                }
            }

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.ghost(Color.theme.textSecondary))

                Button("Finish Setup") {
                    appState.saveSelectedRules(viewModel.getSelectedRules())
                    appState.saveConfiguration(host: viewModel.host, siteId: viewModel.siteId)
                }
                .buttonStyle(.neon(Color.theme.neonGreen))
                .disabled(viewModel.selectedRuleIds.isEmpty)
                .opacity(viewModel.selectedRuleIds.isEmpty ? 0.5 : 1)
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(Color.theme.neonRed)

            Text("No Downtime Rules Found")
                .font(.headline)
                .foregroundColor(.white)

            Text("Create ACL rules with names starting with \"downtime\" in your UniFi Console")
                .font(.subheadline)
                .foregroundColor(Color.theme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.loadRules()
                }
            }
            .buttonStyle(.ghost(Color.theme.neonGreen))
        }
        .padding(32)
        .glassCard()
    }
}

// MARK: - Rule Selection Card

struct RuleSelectionCard: View {
    let rule: ACLRuleDTO
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? Color.theme.neonGreen : Color.theme.textTertiary)

                // Rule info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName(for: rule.name))
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(rule.enabled ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundColor(rule.enabled ? Color.theme.neonGreen : Color.theme.textSecondary)

                        Text("•")
                            .foregroundColor(Color.theme.textTertiary)

                        Text(rule.action)
                            .font(.caption)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.theme.neonGreen.opacity(0.1) : Color.theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.theme.neonGreen.opacity(0.5) : Color.theme.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func displayName(for name: String) -> String {
        let prefix = "downtime-"
        if name.lowercased().hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }
}

// MARK: - Neon Text Field Style

struct NeonTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
            .padding(16)
            .background(Color.theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.glassStroke, lineWidth: 1)
            )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
