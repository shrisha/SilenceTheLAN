import Foundation
import SwiftUI
import SwiftData
import Combine
import os.log

private let logger = Logger(subsystem: "com.silencethelan", category: "AppState")

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var rules: [ACLRule] = []
    @Published var togglingRuleIds: Set<String> = []
    @Published var usingFirewallRules = false  // Track which API type

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
        logger.info("loadConfiguration called")
        guard let context = modelContext else {
            logger.error("loadConfiguration: modelContext is nil!")
            return
        }

        let descriptor = FetchDescriptor<AppConfiguration>()

        if let config = try? context.fetch(descriptor).first,
           config.isConfigured {
            logger.info("loadConfiguration: Found config - host=\(config.unifiHost), siteId=\(config.siteId), usingFirewallRules=\(config.usingFirewallRules)")
            api.configure(host: config.unifiHost, siteId: config.siteId)
            api.restoreSession()  // Try to restore previous session
            logger.info("loadConfiguration: Configuring networkMonitor with host=\(config.unifiHost)")
            networkMonitor.configure(host: config.unifiHost)
            usingFirewallRules = config.usingFirewallRules
            isConfigured = true
            loadCachedRules()
        } else {
            logger.info("loadConfiguration: No configuration found or not configured")
        }
    }

    func saveConfiguration(host: String, siteId: String, usingFirewallRules: Bool = false) {
        logger.info("saveConfiguration called: host=\(host), siteId=\(siteId), usingFirewallRules=\(usingFirewallRules)")
        guard let context = modelContext else {
            logger.error("saveConfiguration: modelContext is nil!")
            return
        }

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
            usingFirewallRules: usingFirewallRules,
            lastUpdated: Date()
        )
        context.insert(config)

        try? context.save()

        api.configure(host: host, siteId: siteId)
        logger.info("saveConfiguration: Configuring networkMonitor with host=\(host)")
        networkMonitor.configure(host: host)
        self.usingFirewallRules = usingFirewallRules
        isConfigured = true
        logger.info("saveConfiguration: Completed, isConfigured=true")
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
        logger.info("loadCachedRules called")
        guard let context = modelContext else {
            logger.error("loadCachedRules: modelContext is nil!")
            return
        }

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected },
            sortBy: [SortDescriptor(\.name)]
        )

        rules = (try? context.fetch(descriptor)) ?? []
        logger.info("loadCachedRules: Loaded \(self.rules.count) selected rules")
        for rule in rules {
            logger.info("  - Rule: \(rule.name), scheduleMode=\(rule.scheduleMode), isEnabled=\(rule.isEnabled), start=\(rule.scheduleStart ?? "nil"), end=\(rule.scheduleEnd ?? "nil")")
        }
    }

    func refreshRules() async {
        logger.info("refreshRules called - checking reachability")
        logger.info("networkMonitor.isReachable = \(self.networkMonitor.isReachable)")
        logger.info("networkMonitor.isConnected = \(self.networkMonitor.isConnected)")
        logger.info("networkMonitor.isWiFi = \(self.networkMonitor.isWiFi)")

        // If not yet reachable, force a reachability check
        // This handles the race condition when transitioning from setup to dashboard
        if !networkMonitor.isReachable {
            logger.info("refreshRules: Not reachable yet - forcing reachability check")
            await networkMonitor.ensureReachabilityChecked()
            logger.info("refreshRules: After check - isReachable = \(self.networkMonitor.isReachable)")
        }

        guard networkMonitor.isReachable else {
            logger.error("refreshRules: Cannot reach UniFi controller - isReachable is false")
            errorMessage = "Cannot reach UniFi controller"
            return
        }

        logger.info("refreshRules: Network is reachable, proceeding with refresh")
        isLoading = true
        errorMessage = nil

        do {
            if usingFirewallRules {
                logger.info("refreshRules: Fetching firewall rules")
                let remoteDTOs = try await api.listFirewallRules()
                logger.info("refreshRules: Got \(remoteDTOs.count) firewall rules")
                await updateCachedRulesFromFirewall(from: remoteDTOs)
            } else {
                logger.info("refreshRules: Fetching ACL rules")
                let remoteDTOs = try await api.listACLRules()
                logger.info("refreshRules: Got \(remoteDTOs.count) ACL rules")
                await updateCachedRules(from: remoteDTOs)
            }
            loadCachedRules()
            logger.info("refreshRules: Completed successfully, \(self.rules.count) rules loaded")
        } catch {
            logger.error("refreshRules: Error - \(error.localizedDescription)")
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

    private func updateCachedRulesFromFirewall(from dtos: [FirewallPolicyDTO]) async {
        guard let context = modelContext else {
            logger.error("updateCachedRulesFromFirewall: No model context!")
            return
        }

        // First, log what we're looking for
        let allCachedRules = (try? context.fetch(FetchDescriptor<ACLRule>())) ?? []
        logger.info("updateCachedRulesFromFirewall: Have \(allCachedRules.count) cached rules, checking against \(dtos.count) API rules")
        for cached in allCachedRules {
            logger.info("  Cached rule ID: \(cached.ruleId), name: \(cached.name)")
        }

        var matchCount = 0
        for dto in dtos {
            let ruleId = dto.id
            let descriptor = FetchDescriptor<ACLRule>(
                predicate: #Predicate { rule in rule.ruleId == ruleId }
            )

            if let existing = try? context.fetch(descriptor).first {
                matchCount += 1
                logger.info("updateCachedRulesFromFirewall: MATCH found - Updating '\(dto.name)' (id=\(dto.id)) - schedule mode=\(dto.schedule?.mode ?? "nil"), start=\(dto.schedule?.timeRangeStart ?? "nil"), end=\(dto.schedule?.timeRangeEnd ?? "nil")")
                // Update existing rule
                existing.isEnabled = dto.enabled
                existing.name = dto.name
                existing.action = dto.action
                existing.index = dto.index ?? 0
                // Update schedule info
                existing.scheduleMode = dto.schedule?.mode ?? "ALWAYS"
                existing.scheduleStart = dto.schedule?.timeRangeStart
                existing.scheduleEnd = dto.schedule?.timeRangeEnd
                existing.lastSynced = Date()
            }
        }

        logger.info("updateCachedRulesFromFirewall: Updated \(matchCount) rules")
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

    func saveSelectedFirewallRules(_ dtos: [FirewallPolicyDTO]) {
        logger.info("saveSelectedFirewallRules called with \(dtos.count) rules")
        guard let context = modelContext else {
            logger.error("saveSelectedFirewallRules: modelContext is nil!")
            return
        }

        // Clear existing rules
        let descriptor = FetchDescriptor<ACLRule>()
        if let existing = try? context.fetch(descriptor) {
            logger.info("saveSelectedFirewallRules: Deleting \(existing.count) existing rules")
            existing.forEach { context.delete($0) }
        }

        // Create new selected rules (reuse ACLRule model, just map the fields)
        for dto in dtos {
            logger.info("saveSelectedFirewallRules: Saving rule '\(dto.name)' with schedule=\(dto.schedule?.mode ?? "nil")")
            let rule = ACLRule(
                ruleId: dto.id,
                ruleType: "FIREWALL",  // Mark as firewall rule
                name: dto.name,
                action: dto.action,
                index: dto.index ?? 0,
                isEnabled: dto.enabled,
                ruleDescription: dto.description,
                scheduleMode: dto.schedule?.mode ?? "ALWAYS",
                scheduleStart: dto.schedule?.timeRangeStart,
                scheduleEnd: dto.schedule?.timeRangeEnd,
                isSelected: true,
                lastSynced: Date()
            )
            context.insert(rule)
        }

        try? context.save()
        loadCachedRules()
        logger.info("saveSelectedFirewallRules: Completed, \(self.rules.count) rules now in memory")
    }

    // MARK: - Add/Remove Individual Rules

    /// Add a single firewall rule to the managed list
    func addFirewallRule(_ dto: FirewallPolicyDTO) {
        guard let context = modelContext else {
            logger.error("addFirewallRule: modelContext is nil!")
            return
        }

        logger.info("addFirewallRule: Adding '\(dto.name)' (id=\(dto.id))")

        let rule = ACLRule(
            ruleId: dto.id,
            ruleType: "FIREWALL",
            name: dto.name,
            action: dto.action,
            index: dto.index ?? 0,
            isEnabled: dto.enabled,
            ruleDescription: dto.description,
            scheduleMode: dto.schedule?.mode ?? "ALWAYS",
            scheduleStart: dto.schedule?.timeRangeStart,
            scheduleEnd: dto.schedule?.timeRangeEnd,
            isSelected: true,
            lastSynced: Date()
        )
        context.insert(rule)

        try? context.save()
        loadCachedRules()
        logger.info("addFirewallRule: Rule added, now managing \(self.rules.count) rules")
    }

    /// Remove a rule from the managed list
    func removeRule(_ rule: ACLRule) {
        guard let context = modelContext else {
            logger.error("removeRule: modelContext is nil!")
            return
        }

        logger.info("removeRule: Removing '\(rule.name)' (id=\(rule.ruleId))")
        context.delete(rule)

        try? context.save()
        loadCachedRules()
        logger.info("removeRule: Rule removed, now managing \(self.rules.count) rules")
    }

    // MARK: - Toggle

    /// Toggle the rule's blocking state
    /// For firewall rules: toggles between ALWAYS (block now) and scheduled mode
    func toggleRule(_ rule: ACLRule) async {
        guard !togglingRuleIds.contains(rule.ruleId) else { return }

        // For firewall rules, toggle = switch between ALWAYS and DAILY schedule
        let wasOverrideActive = rule.isOverrideActive
        let newOverrideState = !wasOverrideActive

        // Store previous state for rollback
        let previousScheduleMode = rule.scheduleMode

        // Optimistic update
        togglingRuleIds.insert(rule.ruleId)
        rule.scheduleMode = newOverrideState ? "ALWAYS" : "DAILY"

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        do {
            if usingFirewallRules {
                // Use schedule-based toggle for firewall rules
                _ = try await api.toggleFirewallSchedule(
                    ruleId: rule.ruleId,
                    blockNow: newOverrideState,
                    scheduleStart: rule.scheduleStart,
                    scheduleEnd: rule.scheduleEnd
                )
            } else {
                // Legacy ACL rules use enabled toggle
                _ = try await api.toggleRule(ruleId: rule.ruleId, enabled: !rule.isEnabled)
                rule.isEnabled = !rule.isEnabled
            }

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            rule.lastSynced = Date()
            try? modelContext?.save()

        } catch {
            // Revert on failure
            rule.scheduleMode = previousScheduleMode

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
