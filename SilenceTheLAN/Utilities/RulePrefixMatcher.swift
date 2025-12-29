import Foundation

/// Centralized utility for matching and processing rule name prefixes.
/// Used to identify which firewall rules should be managed by the app.
struct RulePrefixMatcher {
    /// Default prefixes that are always included
    static let defaultPrefixes = ["Downtime-", "STL-"]

    /// Maximum number of custom prefixes allowed
    static let maxCustomPrefixes = 3

    /// All active prefixes (defaults + custom)
    let prefixes: [String]

    /// Initialize with default prefixes only
    init() {
        self.prefixes = Self.defaultPrefixes
    }

    /// Initialize with custom prefixes added to defaults
    init(customPrefixes: [String]) {
        self.prefixes = Self.defaultPrefixes + Array(customPrefixes.prefix(Self.maxCustomPrefixes))
    }

    /// Initialize with all prefixes from configuration
    init(configuration: AppConfiguration?) {
        if let config = configuration {
            self.prefixes = config.allPrefixes
        } else {
            self.prefixes = Self.defaultPrefixes
        }
    }

    // MARK: - Matching

    /// Check if a rule name matches any of the configured prefixes (case-insensitive)
    func matches(_ ruleName: String) -> Bool {
        let lowercasedName = ruleName.lowercased()
        return prefixes.contains { prefix in
            lowercasedName.hasPrefix(prefix.lowercased())
        }
    }

    /// Get the matching prefix for a rule name (case-insensitive), or nil if no match
    func matchingPrefix(for ruleName: String) -> String? {
        let lowercasedName = ruleName.lowercased()
        return prefixes.first { prefix in
            lowercasedName.hasPrefix(prefix.lowercased())
        }
    }

    // MARK: - Display Name Extraction

    /// Extract display name by removing the matching prefix
    /// e.g., "Downtime-Rishi-Games" -> "Rishi-Games"
    func displayName(for ruleName: String) -> String {
        let lowercasedName = ruleName.lowercased()

        for prefix in prefixes {
            if lowercasedName.hasPrefix(prefix.lowercased()) {
                return String(ruleName.dropFirst(prefix.count))
            }
        }

        return ruleName
    }

    /// Extract person name from rule name
    /// e.g., "Downtime-Rishi-Games" -> "Rishi"
    func personName(for ruleName: String) -> String {
        let display = displayName(for: ruleName)
        let separators = CharacterSet(charactersIn: "- ")
        let parts = display.components(separatedBy: separators)
        return parts.first ?? display
    }

    /// Extract activity name from rule name
    /// e.g., "Downtime-Rishi-Games" -> "Games"
    /// Returns "Internet" if no activity specified
    func activityName(for ruleName: String) -> String {
        let display = displayName(for: ruleName)
        let separators = CharacterSet(charactersIn: "- ")
        let parts = display.components(separatedBy: separators)
        if parts.count > 1 {
            return parts.dropFirst().joined(separator: " ")
        }
        return "Internet"
    }

    // MARK: - Filtering

    /// Filter rules to only those matching configured prefixes and blocking actions
    func filterBlockingRules<T>(_ rules: [T], getName: (T) -> String, getAction: (T) -> String) -> [T] {
        let blockingActions = ["BLOCK", "DROP", "REJECT"]
        return rules.filter { rule in
            matches(getName(rule)) && blockingActions.contains(getAction(rule).uppercased())
        }
    }
}

// MARK: - Global Shared Instance

extension RulePrefixMatcher {
    /// Shared instance that can be updated when configuration changes
    private static var _shared: RulePrefixMatcher = RulePrefixMatcher()

    static var shared: RulePrefixMatcher {
        get { _shared }
        set { _shared = newValue }
    }

    /// Update the shared instance with new configuration
    static func configure(with configuration: AppConfiguration?) {
        _shared = RulePrefixMatcher(configuration: configuration)
    }
}
