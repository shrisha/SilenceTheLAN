import Foundation
import SwiftData
import os.log

private let modelContainerLogger = Logger(subsystem: "com.shrisha.stl", category: "ModelContainer")

enum AppModelContainer {
    static let schema = Schema([
        AppConfiguration.self,
        ACLRule.self
    ])

    static let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
    )

    static let container: ModelContainer = {
        ensureApplicationSupportDirectoryExists()

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func ensureApplicationSupportDirectoryExists() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            modelContainerLogger.error("Unable to resolve Application Support directory")
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true
            )
        } catch {
            modelContainerLogger.error("Failed to create Application Support directory: \(error.localizedDescription)")
        }
    }
}
