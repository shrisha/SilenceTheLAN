import Foundation
import SwiftData

@Model
final class AppConfiguration {
    var unifiHost: String
    var siteId: String
    var isConfigured: Bool
    var lastUpdated: Date

    init(
        unifiHost: String = "",
        siteId: String = "",
        isConfigured: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.unifiHost = unifiHost
        self.siteId = siteId
        self.isConfigured = isConfigured
        self.lastUpdated = lastUpdated
    }
}
