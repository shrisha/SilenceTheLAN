import Foundation
import SwiftData

struct IntentRuleSnapshot: Sendable {
    let ruleId: String
    let name: String
    let personName: String
    let activityName: String
    let action: String
    let scheduleMode: String
    let scheduleStart: String?
    let scheduleEnd: String?
    let originalScheduleStart: String?
    let originalScheduleEnd: String?
    let isEnabled: Bool

    var isPaused: Bool {
        !isEnabled
    }

    var hasOriginalSchedule: Bool {
        originalScheduleStart != nil && originalScheduleEnd != nil
    }

    var isCurrentlyBlocking: Bool {
        let isBlockingAction = ["BLOCK", "DROP", "REJECT"].contains(action.uppercased())
        guard isEnabled && isBlockingAction else { return false }

        switch scheduleMode.uppercased() {
        case "ALWAYS":
            return true
        case "DAILY", "CUSTOM", "EVERY_DAY", "WEEKLY":
            return isTimeWithinSchedule(start: scheduleStart, end: scheduleEnd)
        default:
            return isTimeWithinSchedule(start: scheduleStart, end: scheduleEnd)
        }
    }

    var isWithinOriginalScheduleWindow: Bool {
        isTimeWithinSchedule(start: originalScheduleStart, end: originalScheduleEnd)
    }

    private func isTimeWithinSchedule(start: String?, end: String?) -> Bool {
        guard let startStr = start, let endStr = end else { return false }
        guard let startMinutes = parseTimeToMinutes(startStr),
              let endMinutes = parseTimeToMinutes(endStr) else {
            return false
        }

        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinutes > endMinutes {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
        return currentMinutes >= startMinutes && currentMinutes < endMinutes
    }

    private func parseTimeToMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }
        return (hours * 60) + minutes
    }
}

private struct IntentAppConfigurationSnapshot: Sendable {
    let unifiHost: String
    let siteId: String
    let isConfigured: Bool
}

private struct RuleStateUpdate: Sendable {
    let ruleId: String
    var scheduleMode: String
    var scheduleStart: String?
    var scheduleEnd: String?
    var originalScheduleStart: String?
    var originalScheduleEnd: String?
    var isEnabled: Bool

    init(from snapshot: IntentRuleSnapshot) {
        self.ruleId = snapshot.ruleId
        self.scheduleMode = snapshot.scheduleMode
        self.scheduleStart = snapshot.scheduleStart
        self.scheduleEnd = snapshot.scheduleEnd
        self.originalScheduleStart = snapshot.originalScheduleStart
        self.originalScheduleEnd = snapshot.originalScheduleEnd
        self.isEnabled = snapshot.isEnabled
    }
}

private enum RuleOperation: Sendable {
    case toggleSchedule(blockNow: Bool, scheduleStart: String?, scheduleEnd: String?)
    case pause(paused: Bool)
}

private struct RuleActionPlan: Sendable {
    let shouldExecute: Bool
    let operations: [RuleOperation]
    let updatedState: RuleStateUpdate
}

enum IntentRuleServiceError: LocalizedError {
    case appNotConfigured

    var errorDescription: String? {
        switch self {
        case .appNotConfigured:
            return "The app is not configured yet. Open SilenceTheLAN and finish setup first."
        }
    }
}

@MainActor
final class IntentRuleService {
    static let shared = IntentRuleService()

    private let api = UniFiAPIService()

    func selectedRules() async throws -> [IntentRuleSnapshot] {
        try fetchSelectedRuleSnapshots()
    }

    func selectedRules(forPersonID personID: String) async throws -> [IntentRuleSnapshot] {
        let normalizedPersonID = personID.lowercased()
        let snapshots = try await selectedRules()
        return snapshots.filter { $0.personName.lowercased() == normalizedPersonID }
    }

    func selectedRule(ruleId: String) async throws -> IntentRuleSnapshot? {
        try fetchSelectedRuleSnapshot(ruleId: ruleId)
    }

    func applyPersonAction(personID: String, shouldBlock: Bool) async throws -> [IntentRuleSnapshot] {
        try configureAPIFromStoredConfiguration()

        let rules = try await selectedRules(forPersonID: personID)
        guard !rules.isEmpty else { return [] }

        for rule in rules {
            try await applyRuleActionInternal(rule: rule, shouldBlock: shouldBlock)
        }

        return try await selectedRules(forPersonID: personID)
    }

    func applyRuleAction(ruleId: String, shouldBlock: Bool) async throws -> IntentRuleSnapshot? {
        try configureAPIFromStoredConfiguration()

        guard let rule = try await selectedRule(ruleId: ruleId) else {
            return nil
        }

        try await applyRuleActionInternal(rule: rule, shouldBlock: shouldBlock)
        return try await selectedRule(ruleId: ruleId)
    }

    private func configureAPIFromStoredConfiguration() throws {
        let config = try fetchAppConfigurationSnapshot()

        guard let config, config.isConfigured else {
            throw IntentRuleServiceError.appNotConfigured
        }

        api.configure(host: config.unifiHost, siteId: config.siteId)
    }

    private func applyRuleActionInternal(rule: IntentRuleSnapshot, shouldBlock: Bool) async throws {
        let plan = buildRuleActionPlan(for: rule, shouldBlock: shouldBlock)
        guard plan.shouldExecute else { return }

        for operation in plan.operations {
            switch operation {
            case let .toggleSchedule(blockNow, scheduleStart, scheduleEnd):
                _ = try await api.toggleFirewallSchedule(
                    ruleId: rule.ruleId,
                    blockNow: blockNow,
                    scheduleStart: scheduleStart,
                    scheduleEnd: scheduleEnd
                )
            case let .pause(paused):
                _ = try await api.pauseFirewallRule(ruleId: rule.ruleId, paused: paused)
            }
        }

        try persistRuleStateUpdate(plan.updatedState)
    }

    private func buildRuleActionPlan(for rule: IntentRuleSnapshot, shouldBlock: Bool) -> RuleActionPlan {
        var update = RuleStateUpdate(from: rule)
        var operations: [RuleOperation] = []

        let hasOriginalSchedule = rule.hasOriginalSchedule
        let isInOriginalWindow = rule.isWithinOriginalScheduleWindow
        let isCurrentlyBlocking = rule.isCurrentlyBlocking
        let isPaused = rule.isPaused

        if shouldBlock {
            if isCurrentlyBlocking {
                return RuleActionPlan(shouldExecute: false, operations: [], updatedState: update)
            }

            if isPaused {
                if isInOriginalWindow && hasOriginalSchedule && rule.scheduleMode.uppercased() == "ALWAYS" {
                    update.scheduleMode = "EVERY_DAY"
                    update.scheduleStart = rule.originalScheduleStart
                    update.scheduleEnd = rule.originalScheduleEnd
                    update.isEnabled = true

                    operations.append(
                        .toggleSchedule(
                            blockNow: false,
                            scheduleStart: rule.originalScheduleStart,
                            scheduleEnd: rule.originalScheduleEnd
                        )
                    )
                    operations.append(.pause(paused: false))
                } else if !isInOriginalWindow || !hasOriginalSchedule {
                    update.scheduleMode = "ALWAYS"
                    update.isEnabled = true

                    operations.append(
                        .toggleSchedule(
                            blockNow: true,
                            scheduleStart: rule.originalScheduleStart ?? rule.scheduleStart,
                            scheduleEnd: rule.originalScheduleEnd ?? rule.scheduleEnd
                        )
                    )
                    operations.append(.pause(paused: false))
                } else {
                    update.isEnabled = true
                    operations.append(.pause(paused: false))
                }
            } else {
                if rule.scheduleMode.uppercased() != "ALWAYS",
                   let start = rule.scheduleStart,
                   let end = rule.scheduleEnd,
                   !hasOriginalSchedule {
                    update.originalScheduleStart = start
                    update.originalScheduleEnd = end
                }

                update.scheduleMode = "ALWAYS"
                operations.append(
                    .toggleSchedule(
                        blockNow: true,
                        scheduleStart: update.originalScheduleStart ?? rule.scheduleStart,
                        scheduleEnd: update.originalScheduleEnd ?? rule.scheduleEnd
                    )
                )
            }
        } else {
            if !isCurrentlyBlocking {
                return RuleActionPlan(shouldExecute: false, operations: [], updatedState: update)
            }

            if rule.scheduleMode.uppercased() == "ALWAYS" && hasOriginalSchedule {
                update.scheduleMode = "EVERY_DAY"
                update.scheduleStart = rule.originalScheduleStart
                update.scheduleEnd = rule.originalScheduleEnd

                operations.append(
                    .toggleSchedule(
                        blockNow: false,
                        scheduleStart: rule.originalScheduleStart,
                        scheduleEnd: rule.originalScheduleEnd
                    )
                )

                if isInOriginalWindow {
                    update.isEnabled = false
                    operations.append(.pause(paused: true))
                } else {
                    update.isEnabled = true
                }
            } else {
                update.isEnabled = false
                operations.append(.pause(paused: true))
            }
        }

        return RuleActionPlan(shouldExecute: !operations.isEmpty, operations: operations, updatedState: update)
    }
}

@MainActor
private func fetchSelectedRuleSnapshots() throws -> [IntentRuleSnapshot] {
    let context = ModelContext(SharedModelContainer.container)
    let descriptor = FetchDescriptor<ACLRule>(
        predicate: #Predicate { $0.isSelected }
    )
    return try context.fetch(descriptor).map { makeIntentRuleSnapshot(from: $0) }
}

@MainActor
private func fetchSelectedRuleSnapshot(ruleId: String) throws -> IntentRuleSnapshot? {
    let context = ModelContext(SharedModelContainer.container)
    let descriptor = FetchDescriptor<ACLRule>(
        predicate: #Predicate { $0.ruleId == ruleId && $0.isSelected }
    )
    return try context.fetch(descriptor).first.map { makeIntentRuleSnapshot(from: $0) }
}

@MainActor
private func fetchAppConfigurationSnapshot() throws -> IntentAppConfigurationSnapshot? {
    let context = ModelContext(SharedModelContainer.container)
    let descriptor = FetchDescriptor<AppConfiguration>()
    guard let config = try context.fetch(descriptor).first else { return nil }
    return IntentAppConfigurationSnapshot(
        unifiHost: config.unifiHost,
        siteId: config.siteId,
        isConfigured: config.isConfigured
    )
}

@MainActor
private func persistRuleStateUpdate(_ update: RuleStateUpdate) throws {
    let context = ModelContext(SharedModelContainer.container)
    let targetRuleID = update.ruleId
    let descriptor = FetchDescriptor<ACLRule>(
        predicate: #Predicate { $0.ruleId == targetRuleID }
    )
    guard let rule = try context.fetch(descriptor).first else { return }

    rule.scheduleMode = update.scheduleMode
    rule.scheduleStart = update.scheduleStart
    rule.scheduleEnd = update.scheduleEnd
    rule.originalScheduleStart = update.originalScheduleStart
    rule.originalScheduleEnd = update.originalScheduleEnd
    rule.isEnabled = update.isEnabled
    rule.lastSynced = Date()

    try context.save()
}

private func makeIntentRuleSnapshot(from rule: ACLRule) -> IntentRuleSnapshot {
    IntentRuleSnapshot(
        ruleId: rule.ruleId,
        name: rule.name,
        personName: rule.personName,
        activityName: rule.activityName,
        action: rule.action,
        scheduleMode: rule.scheduleMode,
        scheduleStart: rule.scheduleStart,
        scheduleEnd: rule.scheduleEnd,
        originalScheduleStart: rule.originalScheduleStart,
        originalScheduleEnd: rule.originalScheduleEnd,
        isEnabled: rule.isEnabled
    )
}
