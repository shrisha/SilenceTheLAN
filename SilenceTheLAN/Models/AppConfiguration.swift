import Foundation
import SwiftData

@Model
final class AppConfiguration {
    var unifiHost: String
    var siteId: String
    var isConfigured: Bool
    var usingFirewallRules: Bool  // true = REST API firewall rules, false = Integration API ACL rules
    var lastUpdated: Date

    init(
        unifiHost: String = "",
        siteId: String = "",
        isConfigured: Bool = false,
        usingFirewallRules: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.unifiHost = unifiHost
        self.siteId = siteId
        self.isConfigured = isConfigured
        self.usingFirewallRules = usingFirewallRules
        self.lastUpdated = lastUpdated
    }
}
