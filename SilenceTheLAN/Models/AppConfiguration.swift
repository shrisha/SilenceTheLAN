import Foundation
import SwiftData

@Model
final class AppConfiguration {
    var unifiHost: String
    var siteId: String
    var isConfigured: Bool
    var usingFirewallRules: Bool  // true = REST API firewall rules, false = Integration API ACL rules
    var lastUpdated: Date

    // Custom rule prefixes (stored as JSON array)
    // Default prefixes "Downtime-" and "STL-" are always included
    var customPrefixesJSON: String = "[]"

    init(
        unifiHost: String = "",
        siteId: String = "",
        isConfigured: Bool = false,
        usingFirewallRules: Bool = false,
        lastUpdated: Date = Date(),
        customPrefixes: [String] = []
    ) {
        self.unifiHost = unifiHost
        self.siteId = siteId
        self.isConfigured = isConfigured
        self.usingFirewallRules = usingFirewallRules
        self.lastUpdated = lastUpdated
        self.customPrefixes = customPrefixes
    }

    // MARK: - Custom Prefixes

    /// User-defined custom prefixes (up to 3)
    var customPrefixes: [String] {
        get {
            guard let data = customPrefixesJSON.data(using: .utf8),
                  let prefixes = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return prefixes
        }
        set {
            // Limit to 3 custom prefixes
            let limited = Array(newValue.prefix(3))
            if let data = try? JSONEncoder().encode(limited),
               let json = String(data: data, encoding: .utf8) {
                customPrefixesJSON = json
            }
        }
    }

    /// All active prefixes (defaults + custom)
    var allPrefixes: [String] {
        RulePrefixMatcher.defaultPrefixes + customPrefixes
    }
}
