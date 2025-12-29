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
                .onTapGesture {
                    dismissKeyboard()
                }

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

                    CredentialsStep(viewModel: viewModel)
                        .tag(SetupViewModel.SetupStep.credentials)

                    SiteIdStep(viewModel: viewModel)
                        .tag(SetupViewModel.SetupStep.siteId)

                    RuleSelectionStep(viewModel: viewModel, appState: appState)
                        .tag(SetupViewModel.SetupStep.ruleSelection)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentStep)
            }
        }
        .onChange(of: viewModel.currentStep) { _, _ in
            dismissKeyboard()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Background Effects

    private var backgroundEffects: some View {
        // Simplified - use lower blur and drawingGroup for performance
        ZStack {
            Circle()
                .fill(Color.theme.neonGreen.opacity(0.08))
                .frame(width: 300, height: 300)
                .offset(x: 150, y: -200)
                .blur(radius: 40)

            Circle()
                .fill(Color.theme.neonPurple.opacity(0.05))
                .frame(width: 300, height: 300)
                .offset(x: -150, y: 300)
                .blur(radius: 40)
        }
        .drawingGroup()
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
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Header - compact
                    VStack(spacing: 8) {
                        Text("Find Your UniFi")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Scanning your network for UniFi controller")
                            .font(.subheadline)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    .padding(.top, 24)

                    // Scanning animation or result
                    if viewModel.isLoading {
                        RadarScanView()
                            .frame(height: 180)
                    } else if let host = viewModel.discoveredHost {
                        discoveredHostCard(host: host)
                    } else if isManualEntry {
                        manualEntryCard
                    } else {
                        notFoundView
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }

            // Fixed bottom navigation
            HStack(spacing: 16) {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.ghost(Color.theme.textSecondary))

                if viewModel.discoveredHost != nil || (isManualEntry && !viewModel.host.isEmpty) {
                    Button("Continue") {
                        isHostFieldFocused = false
                        viewModel.nextStep()
                    }
                    .buttonStyle(.neon(Color.theme.neonGreen))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.theme.background)
        }
        .onAppear {
            Task {
                await viewModel.discoverUniFi()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isHostFieldFocused = false
                }
                .foregroundColor(Color.theme.neonGreen)
            }
        }
    }

    private func discoveredHostCard(host: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.theme.neonGreen)

            Text("Found UniFi Controller")
                .font(.headline)
                .foregroundColor(.white)

            Text(host)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Color.theme.neonGreen)
        }
        .padding(24)
        .glassCard()
    }

    private var manualEntryCard: some View {
        VStack(spacing: 16) {
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
        .padding(20)
        .glassCard()
    }

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
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
        .padding(24)
        .glassCard()
    }
}

// MARK: - Credentials Step (Username/Password for REST API)

struct CredentialsStep: View {
    @ObservedObject var viewModel: SetupViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case username, password
    }

    private var isFormValid: Bool {
        !viewModel.username.isEmpty && !viewModel.password.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Spacer to center content when keyboard is hidden
                        Spacer(minLength: 20)
                            .frame(maxHeight: geometry.size.height * 0.08)

                        // Compact header
                        VStack(spacing: 12) {
                            // Icon with subtle glow ring
                            ZStack {
                                Circle()
                                    .stroke(Color.theme.neonPurple.opacity(0.2), lineWidth: 1)
                                    .frame(width: 72, height: 72)

                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.theme.neonPurple, Color.theme.neonBlue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text("Admin Login")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("UniFi local admin credentials")
                                .font(.subheadline)
                                .foregroundColor(Color.theme.textSecondary)
                        }
                        .padding(.bottom, 24)

                        // Login form card
                        VStack(spacing: 0) {
                            // Username field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("USERNAME")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(Color.theme.textTertiary)

                                TextField("", text: $viewModel.username, prompt: Text("admin@example.com").foregroundColor(Color.theme.textTertiary))
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .focused($focusedField, equals: .username)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(Color.theme.background)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                focusedField == .username ? Color.theme.neonGreen.opacity(0.6) : Color.theme.glassStroke,
                                                lineWidth: focusedField == .username ? 1.5 : 1
                                            )
                                    )
                                    .id(Field.username)
                            }

                            Spacer().frame(height: 16)

                            // Password field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PASSWORD")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(Color.theme.textTertiary)

                                SecureField("", text: $viewModel.password, prompt: Text("••••••••").foregroundColor(Color.theme.textTertiary))
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(Color.theme.background)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                focusedField == .password ? Color.theme.neonGreen.opacity(0.6) : Color.theme.glassStroke,
                                                lineWidth: focusedField == .password ? 1.5 : 1
                                            )
                                    )
                                    .id(Field.password)
                            }

                            // Error message
                            if let error = viewModel.errorMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text(error)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(Color.theme.neonRed)
                                .padding(.top, 12)
                            }
                        }
                        .padding(20)
                        .background(Color.theme.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.theme.glassStroke, lineWidth: 1)
                        )

                        // Info hint - minimal
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("Use a local admin account, not your Ubiquiti cloud login")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color.theme.textTertiary)
                        .padding(.top, 12)

                        Spacer(minLength: 24)

                        // Action buttons - inside scroll view
                        VStack(spacing: 12) {
                            // Primary action
                            Button {
                                focusedField = nil
                                Task {
                                    if await viewModel.verifyCredentials() {
                                        viewModel.nextStep()
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Verify & Continue")
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(isFormValid ? Color.theme.neonGreen : Color.theme.neonGreen.opacity(0.3))
                                )
                            }
                            .disabled(!isFormValid || viewModel.isLoading)

                            // Back button
                            Button {
                                focusedField = nil
                                viewModel.previousStep()
                            } label: {
                                Text("Back")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.theme.textSecondary)
                            }
                        }
                        .padding(.bottom, 32)
                        .id("buttons")
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { _, newValue in
                    if let field = newValue {
                        withAnimation(.easeOut(duration: 0.25)) {
                            scrollProxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.theme.neonGreen)
            }
        }
    }
}

// MARK: - Site ID Step

struct SiteIdStep: View {
    @ObservedObject var viewModel: SetupViewModel
    @FocusState private var isSiteIdFieldFocused: Bool
    @State private var showManualEntry = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Header - compact
                    VStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color.theme.neonPurple)

                        Text("Select Site")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(viewModel.availableSites.isEmpty ? "Enter your UniFi Site ID" : "Choose your UniFi site")
                            .font(.subheadline)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    .padding(.top, 16)

                    // Show discovered sites if available
                    if !viewModel.availableSites.isEmpty && !showManualEntry {
                        VStack(spacing: 12) {
                            ForEach(viewModel.availableSites) { site in
                                Button {
                                    viewModel.selectSite(site)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(site.desc ?? site.name)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text(site.name)
                                                .font(.caption)
                                                .foregroundColor(Color.theme.textTertiary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if viewModel.siteId == site.name {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color.theme.neonGreen)
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(viewModel.siteId == site.name ? Color.theme.neonGreen.opacity(0.1) : Color.theme.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(viewModel.siteId == site.name ? Color.theme.neonGreen.opacity(0.5) : Color.theme.glassStroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            Button("Enter manually instead") {
                                withAnimation {
                                    showManualEntry = true
                                }
                            }
                            .font(.caption)
                            .foregroundColor(Color.theme.textSecondary)
                            .padding(.top, 8)
                        }
                    } else {
                        // Manual entry
                        VStack(spacing: 16) {
                            TextField("default or UUID", text: $viewModel.siteId)
                                .textFieldStyle(NeonTextFieldStyle())
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($isSiteIdFieldFocused)

                            Text("Try 'default' first, or find the UUID in your UniFi Console URL")
                                .font(.caption)
                                .foregroundColor(Color.theme.textTertiary)
                                .multilineTextAlignment(.center)

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Color.theme.neonRed)
                            }

                            if !viewModel.availableSites.isEmpty {
                                Button("Show discovered sites") {
                                    withAnimation {
                                        showManualEntry = false
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(Color.theme.neonGreen)
                            }
                        }
                        .padding(16)
                        .glassCard()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)

            // Fixed bottom navigation
            HStack(spacing: 16) {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.ghost(Color.theme.textSecondary))

                Button("Continue") {
                    isSiteIdFieldFocused = false
                    viewModel.nextStep()
                    Task {
                        await viewModel.loadRules()
                    }
                }
                .buttonStyle(.neon(Color.theme.neonGreen))
                .disabled(viewModel.siteId.isEmpty)
                .opacity(viewModel.siteId.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.theme.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isSiteIdFieldFocused = false
                }
                .foregroundColor(Color.theme.neonGreen)
            }
        }
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
            } else if !viewModel.hasAvailableRules {
                Spacer()
                emptyState
                Spacer()
            } else {
                // Select all button
                HStack {
                    Button {
                        if viewModel.selectedRuleIds.count == viewModel.totalAvailableRulesCount {
                            viewModel.deselectAllRules()
                        } else {
                            viewModel.selectAllRules()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.selectedRuleIds.count == viewModel.totalAvailableRulesCount ? "checkmark.square.fill" : "square")
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

                // Rules list - show firewall or ACL rules
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.usingFirewallRules {
                            ForEach(viewModel.availableFirewallRules) { rule in
                                FirewallRuleSelectionCard(
                                    rule: rule,
                                    isSelected: viewModel.selectedRuleIds.contains(rule.id),
                                    onTap: { viewModel.toggleRuleSelection(rule.id) }
                                )
                            }
                        } else {
                            ForEach(viewModel.availableRules, id: \.id) { rule in
                                RuleSelectionCard(
                                    rule: rule,
                                    isSelected: viewModel.selectedRuleIds.contains(rule.id),
                                    onTap: { viewModel.toggleRuleSelection(rule.id) }
                                )
                            }
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
                    if viewModel.usingFirewallRules {
                        appState.saveSelectedFirewallRules(viewModel.getSelectedFirewallRules())
                    } else {
                        appState.saveSelectedRules(viewModel.getSelectedRules())
                    }
                    appState.saveConfiguration(
                        host: viewModel.host,
                        siteId: viewModel.siteId,
                        usingFirewallRules: viewModel.usingFirewallRules
                    )
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

            if let error = viewModel.errorMessage {
                Text("API Error")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(Color.theme.neonRed)
                    .multilineTextAlignment(.center)
            } else {
                Text("No Downtime Rules Found")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Create ACL rules with names starting with \"downtime\" in your UniFi Console")
                    .font(.subheadline)
                    .foregroundColor(Color.theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

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
        RulePrefixMatcher.shared.displayName(for: name)
    }
}

// MARK: - Firewall Rule Selection Card

struct FirewallRuleSelectionCard: View {
    let rule: FirewallPolicyDTO
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

                        Text(actionDisplayName(for: rule.action))
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
        RulePrefixMatcher.shared.displayName(for: name)
    }

    private func actionDisplayName(for action: String) -> String {
        switch action.lowercased() {
        case "drop": return "BLOCK"
        case "accept": return "ALLOW"
        case "reject": return "REJECT"
        default: return action.uppercased()
        }
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
