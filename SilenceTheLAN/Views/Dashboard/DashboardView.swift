import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var headerOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 50

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.theme.background
                    .ignoresSafeArea()

                // Ambient background effects
                backgroundEffects

                VStack(spacing: 0) {
                    // Offline banner
                    if !appState.networkMonitor.isReachable {
                        offlineBanner
                    }

                    // Content
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Header
                            headerView
                                .padding(.top, 20)
                                .opacity(headerOpacity)

                            // Error message
                            if let error = appState.errorMessage {
                                errorBanner(error)
                            }

                            // Rules
                            if appState.rules.isEmpty && !appState.isLoading {
                                emptyState
                            } else {
                                ForEach(appState.rules) { rule in
                                    RuleCard(
                                        rule: rule,
                                        isToggling: appState.togglingRuleIds.contains(rule.ruleId),
                                        onToggle: {
                                            Task {
                                                await appState.toggleRule(rule)
                                            }
                                        }
                                    )
                                    .offset(y: cardsOffset)
                                }
                            }

                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                    }
                    .refreshable {
                        await appState.refreshRules()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.theme.textSecondary, Color.theme.textTertiary],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                headerOpacity = 1
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                cardsOffset = 0
            }
            Task {
                await appState.refreshRules()
            }
        }
    }

    // MARK: - Background Effects

    private var backgroundEffects: some View {
        ZStack {
            // Dynamic glow based on rule states
            ForEach(Array(appState.rules.enumerated()), id: \.element.ruleId) { index, rule in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (rule.isEnabled ? Color.theme.neonGreen : Color.theme.neonRed).opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: index % 2 == 0 ? -100 : 100,
                        y: CGFloat(index * 150) - 100
                    )
                    .blur(radius: 80)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Control")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(appState.rules.count) rules managed")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.textSecondary)
                }
                Spacer()
            }

            // Quick stats - based on actual current blocking status
            HStack(spacing: 16) {
                StatPill(
                    icon: "wifi.slash",
                    count: appState.rules.filter { $0.isCurrentlyBlocking }.count,
                    label: "Blocked",
                    color: Color.theme.neonRed
                )
                StatPill(
                    icon: "checkmark.circle.fill",
                    count: appState.rules.filter { !$0.isCurrentlyBlocking }.count,
                    label: "Allowed",
                    color: Color.theme.neonGreen
                )
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
            Text("Offline - Showing cached data")
                .font(.subheadline)
            Spacer()
        }
        .foregroundColor(Color.theme.neonRed)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.theme.neonRed.opacity(0.15))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.subheadline)
            Spacer()
            Button {
                appState.clearError()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
        }
        .foregroundColor(Color.theme.neonRed)
        .padding(16)
        .glassCard(cornerRadius: 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.router")
                .font(.system(size: 50))
                .foregroundColor(Color.theme.textTertiary)

            Text("No Rules Yet")
                .font(.headline)
                .foregroundColor(.white)

            Text("Add rules in Settings to start\nmanaging your network")
                .font(.subheadline)
                .foregroundColor(Color.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(Color.theme.textSecondary)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(20)
    }
}

// MARK: - Rule Card

struct RuleCard: View {
    @Bindable var rule: ACLRule
    let isToggling: Bool
    let onToggle: () -> Void

    @State private var isPressed = false
    @State private var glowIntensity: Double = 1.0

    // Use the computed properties from ACLRule model
    private var stateColor: Color {
        rule.isCurrentlyBlocking ? Color.theme.neonRed : Color.theme.neonGreen
    }

    private var statusText: String {
        rule.isCurrentlyBlocking ? "BLOCKED" : "ALLOWED"
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 20) {
                // Status indicator with glow
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                    .neonGlow(stateColor, radius: 8 * glowIntensity, isActive: true)
                    .pulse(isActive: rule.isCurrentlyBlocking)

                // Rule info
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.displayName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    // Status and schedule info
                    HStack(spacing: 8) {
                        Text(statusText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(stateColor)

                        if isToggling {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: stateColor))
                                .scaleEffect(0.6)
                        }
                    }

                    // Schedule summary
                    Text(rule.scheduleSummary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.theme.textTertiary)
                }

                Spacer()

                // Toggle switch - ON means "Block Now" override is active
                CustomToggle(isOn: rule.isOverrideActive, color: Color.theme.neonRed)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [stateColor.opacity(0.4), stateColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .neonGlow(stateColor, radius: 15 * glowIntensity, isActive: rule.isCurrentlyBlocking)
            .shimmer(isActive: isToggling)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3)) {
                        isPressed = false
                    }
                }
        )
        .animation(.spring(response: 0.4), value: rule.scheduleMode)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIntensity = 0.6
            }
        }
    }
}

// MARK: - Custom Toggle

struct CustomToggle: View {
    let isOn: Bool
    let color: Color

    var body: some View {
        ZStack {
            // Track
            Capsule()
                .fill(isOn ? color.opacity(0.3) : Color.theme.surface)
                .frame(width: 56, height: 32)
                .overlay(
                    Capsule()
                        .stroke(isOn ? color.opacity(0.5) : Color.theme.glassStroke, lineWidth: 1)
                )

            // Thumb
            Circle()
                .fill(isOn ? color : Color.theme.textSecondary)
                .frame(width: 26, height: 26)
                .neonGlow(color, radius: isOn ? 8 : 0)
                .offset(x: isOn ? 12 : -12)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isOn)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
