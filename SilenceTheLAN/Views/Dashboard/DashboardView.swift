import SwiftUI

// MARK: - Rule Group Model

struct RuleGroup: Identifiable {
    let id: String  // Person name
    let personName: String
    let rules: [ACLRule]

    var blockedCount: Int {
        rules.filter { $0.isCurrentlyBlocking }.count
    }

    var isAnyBlocking: Bool {
        rules.contains { $0.isCurrentlyBlocking }
    }

    var isAllBlocking: Bool {
        rules.allSatisfy { $0.isCurrentlyBlocking }
    }
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var expandedGroups: Set<String> = []

    /// Group rules by person name
    private var ruleGroups: [RuleGroup] {
        let grouped = Dictionary(grouping: appState.rules) { $0.personName }
        return grouped.map { personName, rules in
            RuleGroup(id: personName, personName: personName, rules: rules.sorted { $0.activityName < $1.activityName })
        }.sorted { $0.personName < $1.personName }
    }

    var body: some View {
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
                    LazyVStack(spacing: 12) {
                        // Header
                        headerView

                        // Error message
                        if let error = appState.errorMessage {
                            errorBanner(error)
                        }

                        // Grouped Rules
                        if appState.rules.isEmpty && !appState.isLoading {
                            emptyState
                        } else {
                            ForEach(ruleGroups) { group in
                                PersonGroupCard(
                                    group: group,
                                    isExpanded: expandedGroups.contains(group.id),
                                    togglingRuleIds: appState.togglingRuleIds,
                                    onToggleExpand: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            if expandedGroups.contains(group.id) {
                                                expandedGroups.remove(group.id)
                                            } else {
                                                expandedGroups.insert(group.id)
                                            }
                                        }
                                    },
                                    onToggleAll: { shouldBlock in
                                        Task {
                                            await appState.toggleAllRulesForPerson(group.rules, shouldBlock: shouldBlock)
                                        }
                                    },
                                    onToggleRule: { rule in
                                        Task {
                                            await appState.toggleRule(rule)
                                        }
                                    },
                                    onTemporaryAllow: { rule, minutes in
                                        Task {
                                            await appState.temporaryAllow(rule, minutes: minutes)
                                        }
                                    },
                                    onExtendTemporaryAllow: { rule, minutes in
                                        Task {
                                            await appState.extendTemporaryAllow(rule, minutes: minutes)
                                        }
                                    },
                                    onCancelTemporaryAllow: { rule in
                                        Task {
                                            await appState.cancelTemporaryAllow(rule)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
                .refreshable {
                    await appState.refreshRules()
                }
            }
            .safeAreaPadding(.top)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .onAppear {
            // Expand all groups by default
            if expandedGroups.isEmpty {
                expandedGroups = Set(ruleGroups.map { $0.id })
            }
        }
        .task {
            // Refresh rules on appear (with small delay to let UI render)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await appState.refreshRules()
        }
    }

    // MARK: - Background Effects

    private var backgroundEffects: some View {
        // Simplified static background - no per-rule iteration
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.theme.neonGreen.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -50)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.theme.neonRed.opacity(0.03), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 100, y: 300)
                .blur(radius: 60)
        }
        .drawingGroup() // Rasterize for better performance
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            // Title row with settings
            HStack(alignment: .center) {
                Text("Rules")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                // Quick stats inline
                HStack(spacing: 10) {
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
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(Color.theme.textSecondary)
                        .padding(8)
                }
            }
        }
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

// MARK: - Person Group Card

struct PersonGroupCard: View {
    let group: RuleGroup
    let isExpanded: Bool
    let togglingRuleIds: Set<String>
    let onToggleExpand: () -> Void
    let onToggleAll: (Bool) -> Void
    let onToggleRule: (ACLRule) -> Void
    let onTemporaryAllow: (ACLRule, Int) -> Void
    let onExtendTemporaryAllow: (ACLRule, Int) -> Void
    let onCancelTemporaryAllow: (ACLRule) -> Void

    private var stateColor: Color {
        group.isAnyBlocking ? Color.theme.neonRed : Color.theme.neonGreen
    }

    private var isAnyToggling: Bool {
        group.rules.contains { togglingRuleIds.contains($0.ruleId) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - Person name with master toggle
            Button(action: onToggleExpand) {
                HStack(spacing: 16) {
                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.theme.textTertiary)
                        .frame(width: 16)

                    // Person avatar and name
                    ZStack {
                        Circle()
                            .fill(stateColor.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Text(String(group.personName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(stateColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.personName)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            Text("\(group.rules.count) rule\(group.rules.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(Color.theme.textSecondary)

                            if group.blockedCount > 0 {
                                Text("·")
                                    .foregroundColor(Color.theme.textTertiary)
                                Text("\(group.blockedCount) blocked")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.theme.neonRed)
                            }
                        }
                    }

                    Spacer()

                    // Master toggle for all rules
                    if isAnyToggling {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: stateColor))
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            onToggleAll(!group.isAnyBlocking)
                        } label: {
                            Text(group.isAnyBlocking ? "Allow All" : "Block All")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(group.isAnyBlocking ? Color.theme.neonGreen : Color.theme.neonRed)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill((group.isAnyBlocking ? Color.theme.neonGreen : Color.theme.neonRed).opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke((group.isAnyBlocking ? Color.theme.neonGreen : Color.theme.neonRed).opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Expanded content - individual activity rules
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.rules) { rule in
                        ActivityRuleRow(
                            rule: rule,
                            isToggling: togglingRuleIds.contains(rule.ruleId),
                            onToggle: { onToggleRule(rule) },
                            onTemporaryAllow: { minutes in onTemporaryAllow(rule, minutes) },
                            onExtendTemporaryAllow: { minutes in onExtendTemporaryAllow(rule, minutes) },
                            onCancelTemporaryAllow: { onCancelTemporaryAllow(rule) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [stateColor.opacity(0.3), stateColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Activity Rule Row (Compact)

struct ActivityRuleRow: View {
    @Bindable var rule: ACLRule
    let isToggling: Bool
    let onToggle: () -> Void
    let onTemporaryAllow: (Int) -> Void
    let onExtendTemporaryAllow: (Int) -> Void
    let onCancelTemporaryAllow: () -> Void

    private var stateColor: Color {
        if rule.hasActiveTemporaryAllow {
            return Color.theme.neonAmber
        }
        return rule.isCurrentlyBlocking ? Color.theme.neonRed : Color.theme.neonGreen
    }

    private var activityIcon: String {
        switch rule.activityName.lowercased() {
        case "internet": return "wifi"
        case "games": return "gamecontroller.fill"
        case "youtube": return "play.rectangle.fill"
        case "social": return "bubble.left.and.bubble.right.fill"
        case "streaming": return "tv.fill"
        default: return "app.fill"
        }
    }

    private var statusText: String {
        if let remaining = rule.temporaryAllowTimeRemainingFormatted {
            return "Allowed for \(remaining)"
        }
        return rule.isCurrentlyBlocking ? "BLOCKED" : "ALLOWED"
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Activity icon
                Image(systemName: activityIcon)
                    .font(.system(size: 14))
                    .foregroundColor(stateColor)
                    .frame(width: 24)

                // Activity name and status
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.activityName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text(rule.hasActiveTemporaryAllow ? statusText : rule.scheduleSummary)
                        .font(.system(size: 10))
                        .foregroundColor(rule.hasActiveTemporaryAllow ? stateColor : Color.theme.textTertiary)
                }

                Spacer()

                // Status indicator
                if isToggling {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: stateColor))
                        .scaleEffect(0.6)
                } else {
                    // Compact toggle
                    HStack(spacing: 6) {
                        if rule.hasActiveTemporaryAllow {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                        } else {
                            Circle()
                                .fill(stateColor)
                                .frame(width: 8, height: 8)
                        }

                        Text(statusText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(stateColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(stateColor.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.theme.background.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(stateColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
        .contextMenu {
            if rule.hasActiveTemporaryAllow {
                // Active temporary allow - show cancel/extend options
                Button(role: .destructive) {
                    onCancelTemporaryAllow()
                } label: {
                    Label("Cancel (re-block now)", systemImage: "xmark.circle")
                }

                Divider()

                Button { onExtendTemporaryAllow(15) } label: {
                    Label("Extend by 15 min", systemImage: "clock.badge.plus")
                }
                Button { onExtendTemporaryAllow(30) } label: {
                    Label("Extend by 30 min", systemImage: "clock.badge.plus")
                }
                Button { onExtendTemporaryAllow(60) } label: {
                    Label("Extend by 1 hour", systemImage: "clock.badge.plus")
                }
                Button { onExtendTemporaryAllow(120) } label: {
                    Label("Extend by 2 hours", systemImage: "clock.badge.plus")
                }
            } else if rule.isCurrentlyBlocking {
                // Currently blocking - show temporary allow options
                Button { onTemporaryAllow(15) } label: {
                    Label("Allow 15 min", systemImage: "clock")
                }
                Button { onTemporaryAllow(30) } label: {
                    Label("Allow 30 min", systemImage: "clock")
                }
                Button { onTemporaryAllow(60) } label: {
                    Label("Allow 1 hour", systemImage: "clock")
                }
                Button { onTemporaryAllow(120) } label: {
                    Label("Allow 2 hours", systemImage: "clock")
                }
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
