import Foundation
import SwiftData

@Model
final class ACLRule {
    // Identity
    @Attribute(.unique) var ruleId: String

    // Required fields for PUT requests
    var ruleType: String      // "IPV4" or "IPV6" or "FIREWALL"
    var name: String
    var action: String        // "ALLOW" or "BLOCK"
    var index: Int
    var isEnabled: Bool

    // Optional fields
    var ruleDescription: String?

    // Schedule fields (for firewall policies) - with defaults for migration
    var scheduleMode: String = "ALWAYS"  // "ALWAYS", "DAILY", "WEEKLY", "ONE_TIME", "CUSTOM"
    var scheduleStart: String?    // Time like "23:00" (11 PM)
    var scheduleEnd: String?      // Time like "07:00" (7 AM)
    var scheduleRepeatDaysJSON: String?  // JSON array of days

    // Original schedule (preserved when toggled to ALWAYS, used to restore)
    var originalScheduleStart: String?
    var originalScheduleEnd: String?

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

    /// Whether manual override is active (schedule set to ALWAYS)
    var isOverrideActive: Bool {
        scheduleMode.uppercased() == "ALWAYS"
    }

    /// Whether traffic is currently being blocked based on schedule and current time
    var isCurrentlyBlocking: Bool {
        // UniFi API uses "DROP" for blocking, ACL rules use "BLOCK"
        let isBlockingAction = ["BLOCK", "DROP", "REJECT"].contains(action.uppercased())
        guard isEnabled && isBlockingAction else { return false }

        switch scheduleMode.uppercased() {
        case "ALWAYS":
            return true
        case "DAILY", "CUSTOM", "EVERY_DAY":
            // UniFi API uses various mode names for daily schedules
            return isWithinScheduledTime()
        case "WEEKLY":
            // TODO: Check day of week from repeatOnDays
            return isWithinScheduledTime()
        default:
            return isWithinScheduledTime()
        }
    }

    /// Human-readable schedule summary
    var scheduleSummary: String {
        switch scheduleMode.uppercased() {
        case "ALWAYS":
            return "Manual override active"
        case "DAILY", "CUSTOM", "EVERY_DAY":
            // UniFi API uses various mode names for daily schedules
            if let start = scheduleStart, let end = scheduleEnd {
                return "\(formatTime(start)) - \(formatTime(end))"
            }
            return "Daily schedule"
        case "WEEKLY":
            if let start = scheduleStart, let end = scheduleEnd {
                return "Weekly \(formatTime(start)) - \(formatTime(end))"
            }
            return "Weekly schedule"
        default:
            return "Scheduled"
        }
    }

    /// Check if current time is within the scheduled block window
    private func isWithinScheduledTime() -> Bool {
        guard let startStr = scheduleStart, let endStr = scheduleEnd else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()

        // Parse start and end times
        guard let startMinutes = parseTimeToMinutes(startStr),
              let endMinutes = parseTimeToMinutes(endStr) else {
            return false
        }

        // Get current time in minutes since midnight
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        // Handle overnight schedules (e.g., 23:00 - 07:00)
        if startMinutes > endMinutes {
            // Overnight: blocking if current >= start OR current < end
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            // Same day: blocking if start <= current < end
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }

    /// Parse time string like "23:00" to minutes since midnight
    private func parseTimeToMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }
        return hours * 60 + minutes
    }

    /// Format time for display (e.g., "23:00" -> "11:00 PM")
    private func formatTime(_ time: String) -> String {
        guard let minutes = parseTimeToMinutes(time) else { return time }
        let hours = minutes / 60
        let mins = minutes % 60
        let period = hours >= 12 ? "PM" : "AM"
        let displayHours = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours)
        if mins == 0 {
            return "\(displayHours) \(period)"
        }
        return "\(displayHours):\(String(format: "%02d", mins)) \(period)"
    }

    init(
        ruleId: String,
        ruleType: String = "IPV4",
        name: String,
        action: String = "BLOCK",
        index: Int = 0,
        isEnabled: Bool = false,
        ruleDescription: String? = nil,
        scheduleMode: String = "ALWAYS",
        scheduleStart: String? = nil,
        scheduleEnd: String? = nil,
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
        self.scheduleMode = scheduleMode
        self.scheduleStart = scheduleStart
        self.scheduleEnd = scheduleEnd
        self.isSelected = isSelected
        self.lastSynced = lastSynced
    }
}
