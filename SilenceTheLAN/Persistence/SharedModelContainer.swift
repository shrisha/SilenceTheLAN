import SwiftData

enum SharedModelContainer {
    static let schema = Schema([
        AppConfiguration.self,
        ACLRule.self
    ])

    static let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
    )

    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
