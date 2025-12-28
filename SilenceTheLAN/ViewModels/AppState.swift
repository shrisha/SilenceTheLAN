import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var rules: [ACLRule] = []
    @Published var togglingRuleIds: Set<String> = []

    // MARK: - Services

    let api = UniFiAPIService()
    let networkMonitor = NetworkMonitor.shared

    // MARK: - SwiftData

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadConfiguration()
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<AppConfiguration>()

        if let config = try? context.fetch(descriptor).first,
           config.isConfigured {
            api.configure(host: config.unifiHost, siteId: config.siteId)
            networkMonitor.configure(host: config.unifiHost)
            isConfigured = true
            loadCachedRules()
        }
    }

    func saveConfiguration(host: String, siteId: String) {
        guard let context = modelContext else { return }

        // Delete existing config
        let descriptor = FetchDescriptor<AppConfiguration>()
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }

        // Create new config
        let config = AppConfiguration(
            unifiHost: host,
            siteId: siteId,
            isConfigured: true,
            lastUpdated: Date()
        )
        context.insert(config)

        try? context.save()

        api.configure(host: host, siteId: siteId)
        networkMonitor.configure(host: host)
        isConfigured = true
    }

    func resetConfiguration() {
        guard let context = modelContext else { return }

        // Delete config
        let configDescriptor = FetchDescriptor<AppConfiguration>()
        if let configs = try? context.fetch(configDescriptor) {
            configs.forEach { context.delete($0) }
        }

        // Delete rules
        let ruleDescriptor = FetchDescriptor<ACLRule>()
        if let rules = try? context.fetch(ruleDescriptor) {
            rules.forEach { context.delete($0) }
        }

        try? context.save()
        try? KeychainService.shared.deleteAPIKey()

        isConfigured = false
        rules = []
    }

    // MARK: - Rules

    private func loadCachedRules() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected },
            sortBy: [SortDescriptor(\.name)]
        )

        rules = (try? context.fetch(descriptor)) ?? []
    }

    func refreshRules() async {
        guard networkMonitor.isReachable else {
            errorMessage = "Cannot reach UniFi controller"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let remoteDTOs = try await api.listACLRules()
            await updateCachedRules(from: remoteDTOs)
            loadCachedRules()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func updateCachedRules(from dtos: [ACLRuleDTO]) async {
        guard let context = modelContext else { return }

        for dto in dtos {
            let ruleId = dto.id
            let descriptor = FetchDescriptor<ACLRule>(
                predicate: #Predicate { rule in rule.ruleId == ruleId }
            )

            if let existing = try? context.fetch(descriptor).first {
                // Update existing rule
                existing.isEnabled = dto.enabled
                existing.name = dto.name
                existing.action = dto.action
                existing.index = dto.index
                existing.ruleDescription = dto.description
                existing.lastSynced = Date()
            }
            // Don't create new rules here - that's done during selection
        }

        try? context.save()
    }

    func saveSelectedRules(_ dtos: [ACLRuleDTO]) {
        guard let context = modelContext else { return }

        // Clear existing rules
        let descriptor = FetchDescriptor<ACLRule>()
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }

        // Create new selected rules
        for dto in dtos {
            let rule = ACLRule(
                ruleId: dto.id,
                ruleType: dto.type,
                name: dto.name,
                action: dto.action,
                index: dto.index,
                isEnabled: dto.enabled,
                ruleDescription: dto.description,
                isSelected: true,
                lastSynced: Date()
            )

            // Store filter JSON for PUT requests
            let encoder = JSONEncoder()
            if let sourceFilter = dto.sourceFilter {
                rule.sourceFilterJSON = try? String(data: encoder.encode(sourceFilter), encoding: .utf8)
            }
            if let destFilter = dto.destinationFilter {
                rule.destinationFilterJSON = try? String(data: encoder.encode(destFilter), encoding: .utf8)
            }
            if let protoFilter = dto.protocolFilter {
                rule.protocolFilterJSON = try? String(data: encoder.encode(protoFilter), encoding: .utf8)
            }

            context.insert(rule)
        }

        try? context.save()
        loadCachedRules()
    }

    // MARK: - Toggle

    func toggleRule(_ rule: ACLRule) async {
        guard !togglingRuleIds.contains(rule.ruleId) else { return }

        let previousState = rule.isEnabled
        let newState = !previousState

        // Optimistic update
        togglingRuleIds.insert(rule.ruleId)
        rule.isEnabled = newState

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        do {
            _ = try await api.toggleRule(ruleId: rule.ruleId, enabled: newState)

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            rule.lastSynced = Date()
            try? modelContext?.save()

        } catch {
            // Revert on failure
            rule.isEnabled = previousState

            // Error haptic
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)

            errorMessage = error.localizedDescription
        }

        togglingRuleIds.remove(rule.ruleId)
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
    }
}
