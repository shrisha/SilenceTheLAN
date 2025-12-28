import AppIntents
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.silencethelan", category: "PersonEntity")

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
        logger.info("suggestedEntities() called")

        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let rules = try context.fetch(descriptor)
        logger.info("Found \(rules.count) selected rules")

        // Extract unique person names
        var seenNames = Set<String>()
        var persons: [PersonEntity] = []

        for rule in rules {
            let personName = rule.personName
            let normalizedId = personName.lowercased()
            logger.info("Rule: \(rule.name) -> personName: \(personName), id: \(normalizedId)")

            if !seenNames.contains(normalizedId) {
                seenNames.insert(normalizedId)
                persons.append(PersonEntity(id: normalizedId, displayName: personName))
            }
        }

        logger.info("Returning \(persons.count) unique persons: \(persons.map { $0.displayName }.joined(separator: ", "))")
        return persons.sorted { $0.displayName < $1.displayName }
    }
}

extension PersonEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [PersonEntity] {
        logger.info("entities(matching: '\(string)') called")
        let allPersons = try await suggestedEntities()
        let lowercased = string.lowercased()
        let matches = allPersons.filter { $0.displayName.lowercased().contains(lowercased) }
        logger.info("Matched \(matches.count) persons for '\(string)': \(matches.map { $0.displayName }.joined(separator: ", "))")
        return matches
    }
}
