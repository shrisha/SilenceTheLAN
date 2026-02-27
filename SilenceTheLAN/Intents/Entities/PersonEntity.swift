import AppIntents

struct PersonEntity: AppEntity {
    var id: String
    var displayName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Person"
    static var defaultQuery = PersonEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

struct PersonEntityQuery: EntityQuery {
    func entities(for identifiers: [PersonEntity.ID]) async throws -> [PersonEntity] {
        let allPersons = try await suggestedEntities()
        return allPersons.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PersonEntity] {
        let rules = try await IntentRuleService.shared.selectedRules()

        // Extract unique person names
        var seenNames = Set<String>()
        var persons: [PersonEntity] = []

        for rule in rules {
            let personName = rule.personName
            let normalizedId = personName.lowercased()

            if !seenNames.contains(normalizedId) {
                seenNames.insert(normalizedId)
                persons.append(PersonEntity(id: normalizedId, displayName: personName))
            }
        }

        return persons.sorted { $0.displayName < $1.displayName }
    }
}

extension PersonEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [PersonEntity] {
        let allPersons = try await suggestedEntities()
        let lowercased = string.lowercased()
        return allPersons.filter { $0.displayName.lowercased().contains(lowercased) }
    }
}
