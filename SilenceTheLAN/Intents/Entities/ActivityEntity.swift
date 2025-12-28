import AppIntents
import SwiftData

struct ActivityEntity: AppEntity {
    var id: String
    var personName: String
    var activityName: String
    var ruleId: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static var defaultQuery = ActivityEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(activityName)")
    }

    init(id: String, personName: String, activityName: String, ruleId: String) {
        self.id = id
        self.personName = personName
        self.activityName = activityName
        self.ruleId = ruleId
    }
}

struct ActivityEntityQuery: EntityQuery {
    func entities(for identifiers: [ActivityEntity.ID]) async throws -> [ActivityEntity] {
        let allActivities = try await suggestedEntities()
        return allActivities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ActivityEntity] {
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let rules = try context.fetch(descriptor)

        return rules.map { rule in
            let id = "\(rule.personName.lowercased())-\(rule.activityName.lowercased())"
            return ActivityEntity(
                id: id,
                personName: rule.personName,
                activityName: rule.activityName,
                ruleId: rule.ruleId
            )
        }.sorted { $0.activityName < $1.activityName }
    }
}

extension ActivityEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ActivityEntity] {
        let allActivities = try await suggestedEntities()
        let lowercased = string.lowercased()
        return allActivities.filter {
            $0.activityName.lowercased().contains(lowercased) ||
            $0.personName.lowercased().contains(lowercased)
        }
    }
}
