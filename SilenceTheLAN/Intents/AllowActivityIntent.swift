import AppIntents

struct AllowActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Allow Activity"
    static var description = IntentDescription("Allow a specific activity for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    @Parameter(title: "Activity")
    var activity: ActivityEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let isReachable = await MainActor.run { NetworkMonitor.shared.isReachable }
        guard isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        guard try await IntentRuleService.shared.selectedRule(ruleId: activity.ruleId) != nil else {
            return .result(dialog: "I couldn't find \(activity.activityName) for \(person.displayName)")
        }

        _ = try await IntentRuleService.shared.applyRuleAction(
            ruleId: activity.ruleId,
            shouldBlock: false
        )

        return .result(dialog: "Allowed \(person.displayName)'s \(activity.activityName)")
    }
}
