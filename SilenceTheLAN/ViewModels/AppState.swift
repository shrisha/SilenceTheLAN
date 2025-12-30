import Foundation
import SwiftUI
import SwiftData
import Combine
import os.log
import AppIntents
import UserNotifications

private let logger = Logger(subsystem: "com.silencethelan", category: "AppState")

@MainActor
final class AppState: NSObject, ObservableObject {
    // Shared instance for Siri Intents access
    static let shared = AppState()

    // MARK: - Published State

    @Published var isInitialized = false  // Has configuration been checked?
    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var rules: [ACLRule] = []
    @Published var togglingRuleIds: Set<String> = []

    // MARK: - Audit Trail

    /// Generate audit trail description for transparency in UniFi Console
    private func auditDescription(action: String, context: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeStr = formatter.string(from: Date())

        if let ctx = context {
            return "App: \(action) at \(timeStr) (\(ctx))"
        } else {
            return "App: \(action) at \(timeStr)"
        }
    }

    /// Format time string for display (e.g., "23:00" -> "11 PM")
    private func formatScheduleTime(_ time: String) -> String {
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let hours = Int(parts[0]), let mins = Int(parts[1]) else {
            return time
        }
        let period = hours >= 12 ? "PM" : "AM"
        let displayHours = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours)
        if mins == 0 {
            return "\(displayHours) \(period)"
        }
        return "\(displayHours):\(String(format: "%02d", mins)) \(period)"
    }

    /// Parse time string like "23:00" to minutes since midnight
    private func parseTimeToMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }
        return hours * 60 + minutes
    }

    // MARK: - Services

    let api = UniFiAPIService()
    let networkMonitor = NetworkMonitor.shared

    // MARK: - Refresh State

    private var isRefreshing = false

    // MARK: - SwiftData

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        NotificationService.shared.setDelegate(self)
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
            logger.info("loadConfiguration: Found config - host=\(config.unifiHost), siteId=\(config.siteId)")

            // Configure rule prefix matcher with saved prefixes
            RulePrefixMatcher.configure(with: config)

            // Check if credentials exist - if not, user needs to log in
            guard KeychainService.shared.hasCredentials else {
                logger.info("loadConfiguration: No credentials found, user needs to log in")
                isConfigured = false
                isInitialized = true
                return
            }

            api.configure(host: config.unifiHost, siteId: config.siteId)
            api.restoreSession()  // Try to restore previous session
            logger.info("loadConfiguration: Configuring networkMonitor with host=\(config.unifiHost)")
            networkMonitor.configure(host: config.unifiHost)
            // Load cached rules BEFORE setting isConfigured to avoid empty dashboard flash
            loadCachedRules()
            isConfigured = true
            isInitialized = true
        } else {
            logger.info("loadConfiguration: No configuration found or not configured")
            isInitialized = true
        }
    }

    func saveConfiguration(host: String, siteId: String) {
        logger.info("saveConfiguration called: host=\(host), siteId=\(siteId)")
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
            usingFirewallRules: true,  // Always use firewall rules (REST API)
            lastUpdated: Date()
        )
        context.insert(config)

        try? context.save()

        api.configure(host: host, siteId: siteId)
        logger.info("saveConfiguration: Configuring networkMonitor with host=\(host)")
        networkMonitor.configure(host: host)
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
        try? KeychainService.shared.deleteCredentials()
        try? KeychainService.shared.deleteCSRFToken()
        api.clearSession()

        isConfigured = false
        rules = []
    }

    /// Log out the current user but keep configuration
    func logout() {
        logger.info("Logging out user")

        // Clear session and credentials
        api.clearSession()
        try? KeychainService.shared.deleteCredentials()
        try? KeychainService.shared.deleteCSRFToken()

        // Set unconfigured to trigger login flow
        isConfigured = false
    }

    // MARK: - Rule Prefixes

    /// Get custom prefixes from configuration
    var customPrefixes: [String] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<AppConfiguration>()
        return (try? context.fetch(descriptor).first?.customPrefixes) ?? []
    }

    /// Update custom prefixes and refresh the shared matcher
    func updateCustomPrefixes(_ prefixes: [String]) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<AppConfiguration>()
        if let config = try? context.fetch(descriptor).first {
            config.customPrefixes = prefixes
            try? context.save()

            // Update the shared matcher
            RulePrefixMatcher.configure(with: config)
            logger.info("Updated custom prefixes: \(prefixes)")
        }
    }

    /// Add a custom prefix (max 3)
    func addCustomPrefix(_ prefix: String) {
        var current = customPrefixes
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)

        // Validate: non-empty, not a duplicate, and under limit
        guard !trimmed.isEmpty,
              !current.contains(where: { $0.lowercased() == trimmed.lowercased() }),
              !RulePrefixMatcher.defaultPrefixes.contains(where: { $0.lowercased() == trimmed.lowercased() }),
              current.count < RulePrefixMatcher.maxCustomPrefixes else {
            return
        }

        // Ensure prefix ends with hyphen for consistency
        let normalized = trimmed.hasSuffix("-") ? trimmed : trimmed + "-"
        current.append(normalized)
        updateCustomPrefixes(current)
    }

    /// Remove a custom prefix
    func removeCustomPrefix(_ prefix: String) {
        var current = customPrefixes
        current.removeAll { $0 == prefix }
        updateCustomPrefixes(current)
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
        logger.info("refreshRules called")

        // Prevent concurrent refresh calls
        guard !isRefreshing else {
            logger.info("refreshRules: Already refreshing, skipping")
            return
        }

        isRefreshing = true
        defer {
            logger.info("refreshRules: defer block - setting isRefreshing = false")
            isRefreshing = false
        }

        // Be optimistic - try the API call directly
        // The actual network call will fail if unreachable
        logger.info("refreshRules: Proceeding with refresh")
        isLoading = true
        errorMessage = nil

        do {
            logger.info("refreshRules: About to call api.listFirewallRules()")
            let remoteDTOs = try await api.listFirewallRules()
            logger.info("refreshRules: Got \(remoteDTOs.count) firewall rules")

            // API call succeeded - mark host as reachable
            networkMonitor.markReachable()

            await updateCachedRulesFromFirewall(from: remoteDTOs)
            loadCachedRules()
            logger.info("refreshRules: Completed successfully, \(self.rules.count) rules loaded")

            // Update Siri shortcut parameters with current person/activity names
            SilenceTheLANShortcuts.updateAppShortcutParameters()
        } catch {
            let errorDesc = error.localizedDescription.lowercased()
            // Don't show "cancelled" errors to user - these happen during normal navigation
            if errorDesc.contains("cancel") {
                logger.info("refreshRules: Request was cancelled (normal during navigation)")
            } else if errorDesc.contains("timed out") || errorDesc.contains("network") || errorDesc.contains("connection") {
                // Network error - mark as unreachable
                logger.error("refreshRules: Network error - \(error.localizedDescription)")
                networkMonitor.markUnreachable()
                errorMessage = "Cannot reach UniFi controller"
            } else {
                logger.error("refreshRules: Error - \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
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
                logger.info("updateCachedRulesFromFirewall: MATCH found - '\(dto.name)' (id=\(dto.id))")
                logger.info("  BEFORE UPDATE - Cached: mode=\(existing.scheduleMode), start=\(existing.scheduleStart ?? "nil"), end=\(existing.scheduleEnd ?? "nil")")
                logger.info("  FROM API - mode=\(dto.schedule?.mode ?? "nil"), start=\(dto.schedule?.timeRangeStart ?? "nil"), end=\(dto.schedule?.timeRangeEnd ?? "nil")")

                // Update existing rule
                existing.isEnabled = dto.enabled
                existing.name = dto.name
                existing.action = dto.action
                existing.index = dto.index ?? 0

                // Update schedule info from API
                let newMode = dto.schedule?.mode ?? "ALWAYS"
                existing.scheduleMode = newMode

                // Always update schedule times if API provides them
                if let apiStart = dto.schedule?.timeRangeStart {
                    logger.info("  Updating scheduleStart: '\(existing.scheduleStart ?? "nil")' -> '\(apiStart)'")
                    existing.scheduleStart = apiStart
                    existing.originalScheduleStart = apiStart
                }
                if let apiEnd = dto.schedule?.timeRangeEnd {
                    logger.info("  Updating scheduleEnd: '\(existing.scheduleEnd ?? "nil")' -> '\(apiEnd)'")
                    existing.scheduleEnd = apiEnd
                    existing.originalScheduleEnd = apiEnd
                }
                existing.lastSynced = Date()

                logger.info("  AFTER UPDATE - Cached: mode=\(existing.scheduleMode), start=\(existing.scheduleStart ?? "nil"), end=\(existing.scheduleEnd ?? "nil")")
            }
        }

        logger.info("updateCachedRulesFromFirewall: Updated \(matchCount) rules")
        do {
            try context.save()
            logger.info("updateCachedRulesFromFirewall: Context saved successfully")
        } catch {
            logger.error("updateCachedRulesFromFirewall: Failed to save context - \(error.localizedDescription)")
        }
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
            // Store original schedule times (for restoration when toggling back from ALWAYS)
            if dto.schedule?.mode?.uppercased() != "ALWAYS" {
                rule.originalScheduleStart = dto.schedule?.timeRangeStart
                rule.originalScheduleEnd = dto.schedule?.timeRangeEnd
            }
            context.insert(rule)
        }

        try? context.save()
        loadCachedRules()
        logger.info("saveSelectedFirewallRules: Completed, \(self.rules.count) rules now in memory")

        // Update Siri shortcut parameters with new person/activity names
        SilenceTheLANShortcuts.updateAppShortcutParameters()
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
        // Store original schedule times (for restoration when toggling back from ALWAYS)
        if dto.schedule?.mode?.uppercased() != "ALWAYS" {
            rule.originalScheduleStart = dto.schedule?.timeRangeStart
            rule.originalScheduleEnd = dto.schedule?.timeRangeEnd
        }
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

    // MARK: - Temporary Allow / Delay

    /// Start a temporary allow (if blocking) or delay (if not yet blocking)
    func temporaryAllow(_ rule: ACLRule, minutes: Int) async {
        guard !togglingRuleIds.contains(rule.ruleId) else { return }

        togglingRuleIds.insert(rule.ruleId)
        defer { togglingRuleIds.remove(rule.ruleId) }

        let isCurrentlyBlocking = rule.isCurrentlyBlocking

        // Determine if this is a DELAY or ALLOW scenario
        if !isCurrentlyBlocking, rule.scheduleStart != nil {
            // DELAY scenario: Not blocking yet, push start time forward
            await delayScheduleStart(rule, minutes: minutes)
        } else {
            // ALLOW scenario: Currently blocking, pause temporarily
            await pauseTemporarily(rule, minutes: minutes)
        }
    }

    /// Delay the schedule start time (for rules not yet blocking)
    private func delayScheduleStart(_ rule: ACLRule, minutes: Int) async {
        // Store original start time
        rule.temporaryDelayOriginalStart = rule.scheduleStart
        rule.temporaryDelayExpiry = Date().addingTimeInterval(TimeInterval(minutes * 60))

        do {
            // Calculate new start time
            guard let originalStart = rule.scheduleStart,
                  let startMinutes = parseTimeToMinutes(originalStart) else {
                logger.error("Failed to parse schedule start time")
                errorMessage = "Couldn't delay schedule. Invalid time format."
                return
            }

            let newStartMinutes = (startMinutes + minutes) % (24 * 60) // Wrap at midnight
            let newStartHours = newStartMinutes / 60
            let newStartMins = newStartMinutes % 60
            let newStartTime = String(format: "%02d:%02d", newStartHours, newStartMins)

            // Generate audit trail message
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let delayedUntil = formatScheduleTime(newStartTime)
            let auditMsg = auditDescription(action: "Delayed to \(delayedUntil)", context: "\(minutes)m delay")

            // Update schedule with new start time via API
            logger.info("Delaying schedule: \(originalStart) → \(newStartTime)")
            _ = try await api.toggleFirewallSchedule(
                ruleId: rule.ruleId,
                blockNow: false,
                scheduleStart: newStartTime,
                scheduleEnd: rule.scheduleEnd,
                description: auditMsg
            )

            rule.scheduleStart = newStartTime
            rule.lastSynced = Date()

            // Schedule notification
            if let expiry = rule.temporaryDelayExpiry {
                NotificationService.shared.scheduleTemporaryDelayExpiry(for: rule, at: expiry)
            }

            try? modelContext?.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            logger.info("Delayed schedule start for \(rule.name) by \(minutes) minutes to \(newStartTime)")
        } catch {
            // Rollback on failure
            rule.temporaryDelayExpiry = nil
            rule.temporaryDelayOriginalStart = nil
            logger.error("Failed to delay schedule: \(error.localizedDescription)")
            errorMessage = "Couldn't delay schedule. Try again."
        }
    }

    /// Pause rule temporarily (for currently blocking rules)
    private func pauseTemporarily(_ rule: ACLRule, minutes: Int) async {
        // Store original state
        rule.temporaryAllowOriginalEnabled = rule.isEnabled
        rule.temporaryAllowExpiry = Date().addingTimeInterval(TimeInterval(minutes * 60))

        do {
            // Generate audit trail message
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let expiryStr = timeFormatter.string(from: rule.temporaryAllowExpiry!)
            let auditMsg = auditDescription(action: "Allowed until \(expiryStr)", context: "\(minutes)m extension")

            // Pause the rule to allow traffic (using session auth API)
            _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: true, description: auditMsg)
            rule.isEnabled = false
            rule.lastSynced = Date()

            // Schedule notification
            if let expiry = rule.temporaryAllowExpiry {
                NotificationService.shared.scheduleTemporaryAllowExpiry(for: rule, at: expiry)
            }

            try? modelContext?.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            logger.info("Started temporary allow for \(rule.name) for \(minutes) minutes")
        } catch {
            // Rollback on failure
            rule.temporaryAllowExpiry = nil
            rule.temporaryAllowOriginalEnabled = nil
            logger.error("Failed to start temporary allow: \(error.localizedDescription)")
            errorMessage = "Couldn't allow temporarily. Try again."
        }
    }

    /// Extend an active temporary allow or delay
    func extendTemporaryAllow(_ rule: ACLRule, minutes: Int) async {
        // Check which type of extension this is
        if rule.hasActiveTemporaryDelay {
            await extendDelay(rule, minutes: minutes)
        } else if rule.hasActiveTemporaryAllow {
            await extendAllow(rule, minutes: minutes)
        }
    }

    /// Extend an active delay
    private func extendDelay(_ rule: ACLRule, minutes: Int) async {
        guard let currentStart = rule.scheduleStart,
              let startMinutes = parseTimeToMinutes(currentStart) else {
            return
        }

        let baseTime = max(Date(), rule.temporaryDelayExpiry ?? Date())
        rule.temporaryDelayExpiry = baseTime.addingTimeInterval(TimeInterval(minutes * 60))

        // Calculate new start time (push further)
        let newStartMinutes = (startMinutes + minutes) % (24 * 60)
        let newStartHours = newStartMinutes / 60
        let newStartMins = newStartMinutes % 60
        let newStartTime = String(format: "%02d:%02d", newStartHours, newStartMins)

        // Reschedule notification
        NotificationService.shared.cancelNotification(for: rule.ruleId)
        if let expiry = rule.temporaryDelayExpiry {
            NotificationService.shared.scheduleTemporaryDelayExpiry(for: rule, at: expiry)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Update schedule with new start time
        do {
            let delayedUntil = formatScheduleTime(newStartTime)
            let auditMsg = auditDescription(action: "Delay extended to \(delayedUntil)", context: "+\(minutes)m")

            _ = try await api.toggleFirewallSchedule(
                ruleId: rule.ruleId,
                blockNow: false,
                scheduleStart: newStartTime,
                scheduleEnd: rule.scheduleEnd,
                description: auditMsg
            )

            rule.scheduleStart = newStartTime
            rule.lastSynced = Date()
            logger.info("Extended delay for \(rule.name) to \(newStartTime)")
        } catch {
            logger.warning("Failed to extend delay: \(error.localizedDescription)")
        }

        try? modelContext?.save()
    }

    /// Extend an active temporary allow
    private func extendAllow(_ rule: ACLRule, minutes: Int) async {
        let baseTime = max(Date(), rule.temporaryAllowExpiry ?? Date())
        rule.temporaryAllowExpiry = baseTime.addingTimeInterval(TimeInterval(minutes * 60))

        // Reschedule notification
        NotificationService.shared.cancelNotification(for: rule.ruleId)
        if let expiry = rule.temporaryAllowExpiry {
            NotificationService.shared.scheduleTemporaryAllowExpiry(for: rule, at: expiry)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Update audit trail by re-pausing with new description (rule is already paused)
        do {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let expiryStr = timeFormatter.string(from: rule.temporaryAllowExpiry!)
            let auditMsg = auditDescription(action: "Extended to \(expiryStr)", context: "+\(minutes)m")

            _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: true, description: auditMsg)
            rule.lastSynced = Date()
        } catch {
            logger.warning("Failed to update audit trail for extension: \(error.localizedDescription)")
            // Don't block the extension if audit update fails
        }

        try? modelContext?.save()
        logger.info("Extended temporary allow for \(rule.name) by \(minutes) minutes")
    }

    /// Cancel temporary allow/delay and restore original state
    func cancelTemporaryAllow(_ rule: ACLRule) async {
        guard rule.temporaryAllowExpiry != nil || rule.temporaryDelayExpiry != nil else { return }

        togglingRuleIds.insert(rule.ruleId)
        defer { togglingRuleIds.remove(rule.ruleId) }

        if rule.temporaryDelayExpiry != nil {
            await restoreDelayedSchedule(rule)
        } else {
            await reblockAfterTemporaryAllow(rule)
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Restore original schedule after delay expires
    private func restoreDelayedSchedule(_ rule: ACLRule) async {
        guard let originalStart = rule.temporaryDelayOriginalStart else {
            // No original start time stored, just clear the delay
            rule.temporaryDelayExpiry = nil
            rule.temporaryDelayOriginalStart = nil
            NotificationService.shared.cancelNotification(for: rule.ruleId)
            try? modelContext?.save()
            return
        }

        // Clear delay state
        rule.temporaryDelayExpiry = nil
        rule.temporaryDelayOriginalStart = nil

        // Cancel notification
        NotificationService.shared.cancelNotification(for: rule.ruleId)

        do {
            // Generate audit trail message
            let auditMsg = auditDescription(action: "Schedule restored", context: "delay expired")

            // Restore original schedule start time
            _ = try await api.toggleFirewallSchedule(
                ruleId: rule.ruleId,
                blockNow: false,
                scheduleStart: originalStart,
                scheduleEnd: rule.scheduleEnd,
                description: auditMsg
            )

            rule.scheduleStart = originalStart
            rule.lastSynced = Date()
            try? modelContext?.save()

            logger.info("Restored original schedule for \(rule.name) to \(originalStart)")
        } catch {
            // Keep delay expiry set so we retry on next app open
            rule.temporaryDelayExpiry = Date() // Mark as expired but needing retry
            rule.temporaryDelayOriginalStart = originalStart // Restore for retry
            logger.error("Failed to restore delayed schedule: \(error.localizedDescription)")
            errorMessage = "Couldn't restore schedule for \(rule.displayName). Tap to retry."
        }
    }

    /// Re-block a rule after temporary allow expires
    private func reblockAfterTemporaryAllow(_ rule: ACLRule) async {
        let shouldEnable = rule.temporaryAllowOriginalEnabled ?? true

        // Clear temporary allow state
        rule.temporaryAllowExpiry = nil
        rule.temporaryAllowOriginalEnabled = nil

        // Cancel notification
        NotificationService.shared.cancelNotification(for: rule.ruleId)

        do {
            if shouldEnable {
                // Generate audit trail message
                let auditMsg = auditDescription(action: "Re-blocked", context: "extension expired")

                // Unpause the rule to restore blocking (using session auth API)
                _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: false, description: auditMsg)
                rule.isEnabled = true
            }
            rule.lastSynced = Date()
            try? modelContext?.save()

            logger.info("Re-blocked \(rule.name) after temporary allow")
        } catch {
            // Keep expiry set so we retry on next app open
            rule.temporaryAllowExpiry = Date() // Mark as expired but needing retry
            logger.error("Failed to re-block after temporary allow: \(error.localizedDescription)")
            errorMessage = "Couldn't re-block \(rule.displayName). Tap to retry."
        }
    }

    /// Check for and handle expired temporary allows/delays (call on app becoming active)
    func checkExpiredTemporaryAllows() async {
        let now = Date()

        // Check for expired allows
        let expiredAllows = rules.filter { rule in
            guard let expiry = rule.temporaryAllowExpiry else { return false }
            return expiry <= now
        }

        // Check for expired delays
        let expiredDelays = rules.filter { rule in
            guard let expiry = rule.temporaryDelayExpiry else { return false }
            return expiry <= now
        }

        guard !expiredAllows.isEmpty || !expiredDelays.isEmpty else { return }

        // Handle expired allows
        for rule in expiredAllows {
            await reblockAfterTemporaryAllow(rule)
        }

        // Handle expired delays
        for rule in expiredDelays {
            await restoreDelayedSchedule(rule)
        }

        // Log results
        let allowCount = expiredAllows.count
        let delayCount = expiredDelays.count
        if allowCount > 0 {
            logger.info("Re-blocked \(allowCount) rule(s) after temporary allow expired")
        }
        if delayCount > 0 {
            logger.info("Restored \(delayCount) schedule(s) after delay expired")
        }
    }

    // MARK: - Toggle

    /// Toggle the rule's blocking state
    /// - If currently blocking → Pause (enabled=false) to allow traffic
    /// - If not blocking:
    ///   - If paused → Unpause (enabled=true) to restore schedule behavior
    ///   - If outside schedule → Block Now (set schedule to ALWAYS)
    func toggleRule(_ rule: ACLRule) async {
        guard !togglingRuleIds.contains(rule.ruleId) else { return }

        // If rule has active temporary allow, clear it (user taking manual control)
        if rule.temporaryAllowExpiry != nil {
            rule.temporaryAllowExpiry = nil
            rule.temporaryAllowOriginalEnabled = nil
            NotificationService.shared.cancelNotification(for: rule.ruleId)
        }

        let isCurrentlyBlocking = rule.isCurrentlyBlocking
        let isPaused = !rule.isEnabled

        // Store previous state for rollback
        let previousEnabled = rule.isEnabled
        let previousScheduleMode = rule.scheduleMode

        logger.info("Toggle: isCurrentlyBlocking=\(isCurrentlyBlocking), isPaused=\(isPaused), scheduleMode=\(rule.scheduleMode)")

        // Optimistic update
        togglingRuleIds.insert(rule.ruleId)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        do {
            let hasOriginalSchedule = rule.originalScheduleStart != nil && rule.originalScheduleEnd != nil
            let isInOriginalWindow = rule.isWithinOriginalScheduleWindow

            // Generate audit trail message upfront
            let auditMsg: String
            if isCurrentlyBlocking {
                // Will be allowing
                if let start = rule.originalScheduleStart, let end = rule.originalScheduleEnd {
                    let startFmt = formatScheduleTime(start)
                    let endFmt = formatScheduleTime(end)
                    auditMsg = auditDescription(action: "Allowed", context: "restored to schedule \(startFmt)-\(endFmt)")
                } else {
                    auditMsg = auditDescription(action: "Allowed", context: "paused")
                }
            } else {
                // Will be blocking
                if let start = rule.originalScheduleStart ?? rule.scheduleStart,
                   let end = rule.originalScheduleEnd ?? rule.scheduleEnd {
                    let startFmt = formatScheduleTime(start)
                    let endFmt = formatScheduleTime(end)
                    auditMsg = auditDescription(action: "Blocked", context: "override, normally \(startFmt)-\(endFmt)")
                } else {
                    auditMsg = auditDescription(action: "Blocked", context: "override")
                }
            }

            if isCurrentlyBlocking {
                // ALLOW action: Currently blocking → want to allow traffic
                if rule.scheduleMode.uppercased() == "ALWAYS" && hasOriginalSchedule {
                    // Restore original schedule via API
                    logger.info("Action: RESTORE SCHEDULE (from ALWAYS back to \(rule.originalScheduleStart!)-\(rule.originalScheduleEnd!))")
                    rule.scheduleMode = "EVERY_DAY"
                    rule.scheduleStart = rule.originalScheduleStart
                    rule.scheduleEnd = rule.originalScheduleEnd
                    _ = try await api.toggleFirewallSchedule(
                        ruleId: rule.ruleId,
                        blockNow: false,
                        scheduleStart: rule.originalScheduleStart!,
                        scheduleEnd: rule.originalScheduleEnd!,
                        description: isInOriginalWindow ? nil : auditMsg
                    )

                    if isInOriginalWindow {
                        // Inside schedule window - also pause to allow NOW
                        logger.info("Action: Also PAUSE (inside schedule window)")
                        rule.isEnabled = false
                        _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: true, description: auditMsg)
                    } else {
                        // Outside schedule window - traffic allowed by schedule
                        rule.isEnabled = true
                    }
                } else {
                    // Blocking by schedule - just pause
                    logger.info("Action: PAUSE (allow traffic)")
                    rule.isEnabled = false
                    _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: true, description: auditMsg)
                }
            } else if isPaused {
                // BLOCK action: Currently paused → want to block traffic
                if isInOriginalWindow && hasOriginalSchedule && rule.scheduleMode.uppercased() == "ALWAYS" {
                    // Inside original schedule window - restore schedule + unpause (schedule will block)
                    logger.info("Action: RESTORE SCHEDULE + UNPAUSE (inside window, schedule will block)")
                    rule.scheduleMode = "EVERY_DAY"
                    rule.scheduleStart = rule.originalScheduleStart
                    rule.scheduleEnd = rule.originalScheduleEnd
                    rule.isEnabled = true
                    _ = try await api.toggleFirewallSchedule(
                        ruleId: rule.ruleId,
                        blockNow: false,
                        scheduleStart: rule.originalScheduleStart!,
                        scheduleEnd: rule.originalScheduleEnd!
                    )
                    // Unpause after restoring schedule
                    _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: false, description: auditMsg)
                } else if !isInOriginalWindow || !hasOriginalSchedule {
                    // Outside schedule window OR no original schedule - set to ALWAYS + unpause
                    logger.info("Action: BLOCK NOW (set ALWAYS + unpause)")
                    rule.scheduleMode = "ALWAYS"
                    rule.isEnabled = true
                    _ = try await api.toggleFirewallSchedule(
                        ruleId: rule.ruleId,
                        blockNow: true,
                        scheduleStart: rule.originalScheduleStart ?? rule.scheduleStart,
                        scheduleEnd: rule.originalScheduleEnd ?? rule.scheduleEnd
                    )
                    // Also unpause the rule
                    _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: false, description: auditMsg)
                } else {
                    // Has schedule, inside window - just unpause
                    logger.info("Action: UNPAUSE (schedule will block)")
                    rule.isEnabled = true
                    _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: false, description: auditMsg)
                }
            } else {
                // BLOCK action: Outside schedule window (not paused) → Block Now
                logger.info("Action: BLOCK NOW (set ALWAYS)")

                // Preserve original schedule before changing to ALWAYS
                if rule.scheduleMode.uppercased() != "ALWAYS" &&
                   rule.scheduleStart != nil && rule.scheduleEnd != nil {
                    rule.originalScheduleStart = rule.scheduleStart
                    rule.originalScheduleEnd = rule.scheduleEnd
                    logger.info("Preserved original schedule: \(rule.scheduleStart ?? "nil") - \(rule.scheduleEnd ?? "nil")")
                }

                rule.scheduleMode = "ALWAYS"
                _ = try await api.toggleFirewallSchedule(
                    ruleId: rule.ruleId,
                    blockNow: true,
                    scheduleStart: rule.originalScheduleStart ?? rule.scheduleStart,
                    scheduleEnd: rule.originalScheduleEnd ?? rule.scheduleEnd,
                    description: auditMsg
                )
            }

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            // Prepare audit trail message (already included in API calls above via description parameter)
            // No separate API call needed

            rule.lastSynced = Date()
            try? modelContext?.save()

        } catch {
            // Revert on failure
            rule.isEnabled = previousEnabled
            rule.scheduleMode = previousScheduleMode

            // Error haptic
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)

            errorMessage = error.localizedDescription
        }

        togglingRuleIds.remove(rule.ruleId)
    }

    /// Toggle all rules for a person (group toggle)
    /// - shouldBlock: if true, block all; if false, allow all (pause)
    func toggleAllRulesForPerson(_ rules: [ACLRule], shouldBlock: Bool) async {
        guard !rules.isEmpty else { return }

        // Mark all as toggling
        for rule in rules {
            togglingRuleIds.insert(rule.ruleId)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Toggle each rule
        for rule in rules {
            let isCurrentlyBlocking = rule.isCurrentlyBlocking
            let isPaused = !rule.isEnabled

            // Skip if already in desired state
            if shouldBlock && isCurrentlyBlocking {
                togglingRuleIds.remove(rule.ruleId)
                continue
            }
            if !shouldBlock && !isCurrentlyBlocking {
                togglingRuleIds.remove(rule.ruleId)
                continue
            }

            // Store previous state for rollback
            let previousEnabled = rule.isEnabled
            let previousScheduleMode = rule.scheduleMode

            do {
                let hasOriginalSchedule = rule.originalScheduleStart != nil && rule.originalScheduleEnd != nil
                let isInOriginalWindow = rule.isWithinOriginalScheduleWindow

                if shouldBlock {
                    // BLOCK action - use same logic as individual toggleRule
                    if isPaused {
                        if isInOriginalWindow && hasOriginalSchedule && rule.scheduleMode.uppercased() == "ALWAYS" {
                            // Inside original schedule window - restore schedule + unpause
                            logger.info("toggleAllRulesForPerson: RESTORE SCHEDULE + UNPAUSE \(rule.name)")
                            rule.scheduleMode = "EVERY_DAY"
                            rule.scheduleStart = rule.originalScheduleStart
                            rule.scheduleEnd = rule.originalScheduleEnd
                            rule.isEnabled = true
                            _ = try await api.toggleFirewallSchedule(
                                ruleId: rule.ruleId,
                                blockNow: false,
                                scheduleStart: rule.originalScheduleStart!,
                                scheduleEnd: rule.originalScheduleEnd!
                            )
                            _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: false)
                        } else if !isInOriginalWindow || !hasOriginalSchedule {
                            // Outside schedule window OR no original schedule - set to ALWAYS + unpause
                            logger.info("toggleAllRulesForPerson: BLOCK NOW (ALWAYS + unpause) \(rule.name)")
                            rule.scheduleMode = "ALWAYS"
                            rule.isEnabled = true
                            _ = try await api.toggleFirewallSchedule(
                                ruleId: rule.ruleId,
                                blockNow: true,
                                scheduleStart: rule.originalScheduleStart ?? rule.scheduleStart,
                                scheduleEnd: rule.originalScheduleEnd ?? rule.scheduleEnd
                            )
                            // Also unpause the rule
                            _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: false)
                        } else {
                            // Has schedule, inside window - just unpause
                            logger.info("toggleAllRulesForPerson: UNPAUSE \(rule.name)")
                            rule.isEnabled = true
                            _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: false)
                        }
                    } else {
                        // Not paused but not blocking (outside schedule) → set to ALWAYS
                        logger.info("toggleAllRulesForPerson: BLOCK NOW (ALWAYS) \(rule.name)")
                        if rule.scheduleMode.uppercased() != "ALWAYS" &&
                           rule.scheduleStart != nil && rule.scheduleEnd != nil {
                            rule.originalScheduleStart = rule.scheduleStart
                            rule.originalScheduleEnd = rule.scheduleEnd
                        }
                        rule.scheduleMode = "ALWAYS"
                        _ = try await api.toggleFirewallSchedule(
                            ruleId: rule.ruleId,
                            blockNow: true,
                            scheduleStart: rule.originalScheduleStart ?? rule.scheduleStart,
                            scheduleEnd: rule.originalScheduleEnd ?? rule.scheduleEnd
                        )
                    }
                } else {
                    // ALLOW action - use same logic as individual toggleRule
                    if rule.scheduleMode.uppercased() == "ALWAYS" && hasOriginalSchedule {
                        // Restore original schedule
                        logger.info("toggleAllRulesForPerson: RESTORE SCHEDULE \(rule.name)")
                        rule.scheduleMode = "EVERY_DAY"
                        rule.scheduleStart = rule.originalScheduleStart
                        rule.scheduleEnd = rule.originalScheduleEnd
                        _ = try await api.toggleFirewallSchedule(
                            ruleId: rule.ruleId,
                            blockNow: false,
                            scheduleStart: rule.originalScheduleStart!,
                            scheduleEnd: rule.originalScheduleEnd!
                        )

                        if isInOriginalWindow {
                            // Inside window - also pause
                            logger.info("toggleAllRulesForPerson: Also PAUSE \(rule.name)")
                            rule.isEnabled = false
                            _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: true)
                        } else {
                            rule.isEnabled = true
                        }
                    } else {
                        // Just pause
                        logger.info("toggleAllRulesForPerson: PAUSE \(rule.name)")
                        rule.isEnabled = false
                        _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: true)
                    }
                }

                rule.lastSynced = Date()
            } catch {
                // Revert on failure
                rule.isEnabled = previousEnabled
                rule.scheduleMode = previousScheduleMode
                logger.error("toggleAllRulesForPerson: Failed for rule \(rule.name) - \(error.localizedDescription)")
            }

            togglingRuleIds.remove(rule.ruleId)
        }

        // Save all changes
        try? modelContext?.save()

        // Success haptic
        let successGenerator = UINotificationFeedbackGenerator()
        successGenerator.notificationOccurred(.success)
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Notification Handling

extension AppState: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let ruleId = userInfo["ruleId"] as? String else {
            completionHandler()
            return
        }

        Task { @MainActor in
            guard let rule = rules.first(where: { $0.ruleId == ruleId }) else {
                completionHandler()
                return
            }

            switch response.actionIdentifier {
            case "REBLOCK_NOW":
                await cancelTemporaryAllow(rule)
            case "EXTEND_15":
                await extendTemporaryAllow(rule, minutes: 15)
            case UNNotificationDefaultActionIdentifier:
                // User tapped notification body - check all expired
                await checkExpiredTemporaryAllows()
            default:
                break
            }

            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
