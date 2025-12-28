import AppIntents
import SwiftData

struct AllowPersonIntent: AppIntent {
    static var title: LocalizedStringResource = "Allow Person"
    static var description = IntentDescription("Allow all internet access for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Check network reachability
        guard NetworkMonitor.shared.isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        // 2. Get rules for this person
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let allRules = try context.fetch(descriptor)
        let personId = person.id.lowercased()
        let rules = allRules.filter { $0.personName.lowercased() == personId }

        guard !rules.isEmpty else {
            return .result(dialog: "I couldn't find anyone named \(person.displayName) in your rules")
        }

        // 3. Ensure AppState is configured
        let appState = AppState.shared
        if appState.rules.isEmpty {
            appState.configure(modelContext: context)
        }

        // 4. Allow all rules for this person
        await appState.toggleAllRulesForPerson(rules, shouldBlock: false)

        // 5. Return summary
        let activities = rules.map { $0.activityName }.joined(separator: ", ")
        return .result(dialog: "Allowed \(person.displayName). \(rules.count) rules affected: \(activities)")
    }
}
