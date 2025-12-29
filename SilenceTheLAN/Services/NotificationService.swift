import Foundation
import UserNotifications

final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let categoryIdentifier = "TEMP_ALLOW_EXPIRY"

    private override init() {
        super.init()
        setupCategories()
    }

    // MARK: - Setup

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization failed: \(error)")
            return false
        }
    }

    private func setupCategories() {
        let reblockAction = UNNotificationAction(
            identifier: "REBLOCK_NOW",
            title: "Re-block Now",
            options: [.foreground]
        )

        let extendAction = UNNotificationAction(
            identifier: "EXTEND_15",
            title: "Extend 15 min",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [reblockAction, extendAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - Schedule / Cancel

    func scheduleTemporaryAllowExpiry(for rule: ACLRule, at expiryDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "\(rule.displayName)'s internet access is ending"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["ruleId": rule.ruleId]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, expiryDate.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: rule.ruleId),
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func cancelNotification(for ruleId: String) {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: ruleId)]
        )
    }

    private func notificationIdentifier(for ruleId: String) -> String {
        "temp-allow-\(ruleId)"
    }

    // MARK: - Delegate Setup

    func setDelegate(_ delegate: UNUserNotificationCenterDelegate) {
        notificationCenter.delegate = delegate
    }
}
