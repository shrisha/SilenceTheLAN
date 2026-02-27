import AppIntents

struct AllowPersonIntent: AppIntent {
    static var title: LocalizedStringResource = "Allow Person"
    static var description = IntentDescription("Allow all internet access for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let isReachable = await MainActor.run { NetworkMonitor.shared.isReachable }
        guard isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        let personId = person.id.lowercased()
        let rules = try await IntentRuleService.shared.applyPersonAction(
            personID: personId,
            shouldBlock: false
        )

        guard !rules.isEmpty else {
            return .result(dialog: "I couldn't find anyone named \(person.displayName) in your rules")
        }

        let activities = rules.map { $0.activityName }.joined(separator: ", ")
        return .result(dialog: "Allowed \(person.displayName). \(rules.count) rules affected: \(activities)")
    }
}
