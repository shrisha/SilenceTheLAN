import Foundation
import SwiftData

@Model
final class ACLRule {
    // Identity
    @Attribute(.unique) var ruleId: String

    // Required fields for PUT requests
    var ruleType: String      // "IPV4" or "IPV6"
    var name: String
    var action: String        // "ALLOW" or "BLOCK"
    var index: Int
    var isEnabled: Bool

    // Optional fields
    var ruleDescription: String?

    // App-specific
    var isSelected: Bool
    var lastSynced: Date

    // Store complex filter objects as JSON for PUT requests
    var sourceFilterJSON: String?
    var destinationFilterJSON: String?
    var protocolFilterJSON: String?
    var enforcingDeviceFilterJSON: String?

    /// Display name extracted from rule name (e.g., "Downtime-Rishi" -> "Rishi")
    var displayName: String {
        let prefix = "downtime-"
        if name.lowercased().hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }

    init(
        ruleId: String,
        ruleType: String = "IPV4",
        name: String,
        action: String = "BLOCK",
        index: Int = 0,
        isEnabled: Bool = false,
        ruleDescription: String? = nil,
        isSelected: Bool = false,
        lastSynced: Date = Date()
    ) {
        self.ruleId = ruleId
        self.ruleType = ruleType
        self.name = name
        self.action = action
        self.index = index
        self.isEnabled = isEnabled
        self.ruleDescription = ruleDescription
        self.isSelected = isSelected
        self.lastSynced = lastSynced
    }
}
