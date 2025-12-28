import AppIntents
import SwiftData

struct AllowActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Allow Activity"
    static var description = IntentDescription("Allow a specific activity for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    @Parameter(title: "Activity")
    var activity: ActivityEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Check network reachability
        guard NetworkMonitor.shared.isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        // 2. Find the specific rule
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let ruleId = activity.ruleId
        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.ruleId == ruleId && $0.isSelected }
        )

        guard let rule = try context.fetch(descriptor).first else {
            return .result(dialog: "I couldn't find \(activity.activityName) for \(person.displayName)")
        }

        // 3. Ensure AppState is configured
        let appState = AppState.shared
        if appState.rules.isEmpty {
            appState.configure(modelContext: context)
        }

        // 4. Allow this specific rule (if currently blocking)
        if rule.isCurrentlyBlocking {
            await appState.toggleRule(rule)
        }

        // 5. Return confirmation
        return .result(dialog: "Allowed \(person.displayName)'s \(activity.activityName)")
    }
}
