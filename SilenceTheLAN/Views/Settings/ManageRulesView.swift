import SwiftUI

struct ManageRulesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var availableRules: [FirewallPolicyDTO] = []
    @State private var managedRuleIds: Set<String> = []
    @State private var staleRuleIds: Set<String> = []

    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                rulesListView
            }
        }
        .navigationTitle("Manage Rules")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadRules()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.neonGreen))
                .scaleEffect(1.5)
            Text("Loading rules...")
                .font(.subheadline)
                .foregroundColor(Color.theme.textSecondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(Color.theme.neonRed)

            Text("Failed to Load Rules")
                .font(.headline)
                .foregroundColor(.white)

            Text(error)
                .font(.subheadline)
                .foregroundColor(Color.theme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadRules()
                }
            }
            .buttonStyle(.neon(Color.theme.neonGreen))
        }
        .padding(32)
    }

    // MARK: - Rules List View

    private var rulesListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stale Rules Section (if any)
                if !staleRules.isEmpty {
                    staleRulesSection
                }

                // Currently Managed Rules
                if !managedRules.isEmpty {
                    managedRulesSection
                }

                // Available Rules to Add
                if !unmangedRules.isEmpty {
                    availableRulesSection
                }

                // Empty state
                if managedRules.isEmpty && unmangedRules.isEmpty && staleRules.isEmpty {
                    emptyState
                }

                Spacer()
                    .frame(height: 50)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .refreshable {
            await loadRules()
        }
    }

    // MARK: - Stale Rules Section

    private var staleRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color.theme.neonRed)
                Text("NO LONGER IN UNIFI")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Color.theme.neonRed)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(staleRules, id: \.ruleId) { rule in
                    StaleRuleRow(rule: rule) {
                        removeRule(rule)
                    }

                    if rule.ruleId != staleRules.last?.ruleId {
                        Divider()
                            .background(Color.theme.glassStroke)
                    }
                }
            }
            .background(Color.theme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.theme.neonRed.opacity(0.5), lineWidth: 1)
            )
        }
    }

    // MARK: - Managed Rules Section

    private var managedRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MANAGED")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color.theme.textTertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(managedRules, id: \.ruleId) { rule in
                    ManagedRuleRow(rule: rule) {
                        removeRule(rule)
                    }

                    if rule.ruleId != managedRules.last?.ruleId {
                        Divider()
                            .background(Color.theme.glassStroke)
                    }
                }
            }
            .background(Color.theme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.theme.glassStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Available Rules Section

    private var availableRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AVAILABLE TO ADD")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color.theme.textTertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(unmangedRules, id: \.id) { rule in
                    AvailableRuleRow(rule: rule) {
                        addRule(rule)
                    }

                    if rule.id != unmangedRules.last?.id {
                        Divider()
                            .background(Color.theme.glassStroke)
                    }
                }
            }
            .background(Color.theme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.theme.glassStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(Color.theme.textTertiary)

            Text("No Downtime Rules")
                .font(.headline)
                .foregroundColor(.white)

            Text("Create firewall rules in UniFi that start with \"Downtime\" and have action set to BLOCK")
                .font(.subheadline)
                .foregroundColor(Color.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Computed Properties

    private var managedRules: [ACLRule] {
        appState.rules.filter { !staleRuleIds.contains($0.ruleId) }
    }

    private var staleRules: [ACLRule] {
        appState.rules.filter { staleRuleIds.contains($0.ruleId) }
    }

    private var unmangedRules: [FirewallPolicyDTO] {
        let matcher = RulePrefixMatcher.shared
        let matchingRules = matcher.filterBlockingRules(
            availableRules,
            getName: { $0.name },
            getAction: { $0.action }
        )
        return matchingRules.filter { !managedRuleIds.contains($0.id) }
    }

    // MARK: - Actions

    private func loadRules() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch fresh rules from API
            let remoteRules = try await appState.api.listFirewallRules()
            availableRules = remoteRules

            // Build set of remote rule IDs
            let remoteIds = Set(remoteRules.map { $0.id })

            // Build set of managed rule IDs
            managedRuleIds = Set(appState.rules.map { $0.ruleId })

            // Find stale rules (in app but not in UniFi)
            staleRuleIds = managedRuleIds.subtracting(remoteIds)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func addRule(_ dto: FirewallPolicyDTO) {
        appState.addFirewallRule(dto)
        managedRuleIds.insert(dto.id)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func removeRule(_ rule: ACLRule) {
        appState.removeRule(rule)
        managedRuleIds.remove(rule.ruleId)
        staleRuleIds.remove(rule.ruleId)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Managed Rule Row

struct ManagedRuleRow: View {
    let rule: ACLRule
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(rule.isCurrentlyBlocking ? Color.theme.neonRed : Color.theme.neonGreen)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                    .font(.body)
                    .foregroundColor(.white)

                Text(rule.scheduleSummary)
                    .font(.caption)
                    .foregroundColor(Color.theme.textTertiary)
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.theme.neonRed.opacity(0.8))
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

// MARK: - Stale Rule Row

struct StaleRuleRow: View {
    let rule: ACLRule
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.theme.neonRed)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                    .font(.body)
                    .foregroundColor(.white)

                Text("Rule deleted from UniFi")
                    .font(.caption)
                    .foregroundColor(Color.theme.neonRed)
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Text("Remove")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.theme.neonRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.theme.neonRed.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

// MARK: - Available Rule Row

struct AvailableRuleRow: View {
    let rule: FirewallPolicyDTO
    let onAdd: () -> Void

    private var displayName: String {
        RulePrefixMatcher.shared.displayName(for: rule.name)
    }

    private var scheduleText: String {
        guard let schedule = rule.schedule else { return "No schedule" }
        if schedule.mode?.uppercased() == "ALWAYS" {
            return "Always active"
        }
        if let start = schedule.timeRangeStart, let end = schedule.timeRangeEnd {
            return "\(start) - \(end)"
        }
        return schedule.mode ?? "Scheduled"
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .stroke(Color.theme.textTertiary, lineWidth: 2)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                    .foregroundColor(.white)

                Text(scheduleText)
                    .font(.caption)
                    .foregroundColor(Color.theme.textTertiary)
            }

            Spacer()

            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.theme.neonGreen)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ManageRulesView()
            .environmentObject(AppState())
    }
}
