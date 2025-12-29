# Temporary Allow Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to temporarily unblock a rule for 15m/30m/1h/2h with automatic re-blocking on expiry.

**Architecture:** Client-side only using local notifications and on-app-open checks. Data stored in SwiftData, notifications via UNUserNotificationCenter. Context menu triggers temporary allow, timer refreshes UI.

**Tech Stack:** SwiftUI, SwiftData, UserNotifications framework

---

### Task 1: Add Amber Color to Theme

**Files:**
- Modify: `SilenceTheLAN/Views/Theme.swift:16-19`

**Step 1: Add neonAmber color**

In `ThemeColors` struct, add after `neonPurple`:

```swift
let neonAmber = Color(red: 1, green: 0.75, blue: 0) // #FFBF00
```

**Step 2: Commit**

```bash
git add SilenceTheLAN/Views/Theme.swift
git commit -m "feat: add neonAmber color to theme for temporary allow state"
```

---

### Task 2: Add Data Model Fields to ACLRule

**Files:**
- Modify: `SilenceTheLAN/Models/ACLRule.swift:29-31`

**Step 1: Add temporary allow fields**

After `var lastSynced: Date` (line 31), add:

```swift
// Temporary allow tracking
var temporaryAllowExpiry: Date?           // When temp allow expires (nil = not active)
var temporaryAllowOriginalEnabled: Bool?  // Was rule enabled before temp allow?
```

**Step 2: Add computed property for active temporary allow**

After the `activityName` computed property (around line 53), add:

```swift
/// Whether a temporary allow is currently active
var hasActiveTemporaryAllow: Bool {
    guard let expiry = temporaryAllowExpiry else { return false }
    return expiry > Date()
}

/// Time remaining for temporary allow (nil if not active)
var temporaryAllowTimeRemaining: TimeInterval? {
    guard let expiry = temporaryAllowExpiry, expiry > Date() else { return nil }
    return expiry.timeIntervalSinceNow
}

/// Formatted time remaining string (e.g., "23 min" or "1h 30m")
var temporaryAllowTimeRemainingFormatted: String? {
    guard let remaining = temporaryAllowTimeRemaining else { return nil }
    let minutes = Int(remaining / 60)
    if minutes < 60 {
        return "\(minutes) min"
    } else {
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}
```

**Step 3: Commit**

```bash
git add SilenceTheLAN/Models/ACLRule.swift
git commit -m "feat: add temporary allow tracking fields to ACLRule"
```

---

### Task 3: Create NotificationService

**Files:**
- Create: `SilenceTheLAN/Services/NotificationService.swift`

**Step 1: Create the notification service**

```swift
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
```

**Step 2: Commit**

```bash
git add SilenceTheLAN/Services/NotificationService.swift
git commit -m "feat: add NotificationService for temporary allow expiry notifications"
```

---

### Task 4: Add Temporary Allow Methods to AppState

**Files:**
- Modify: `SilenceTheLAN/ViewModels/AppState.swift`

**Step 1: Add import for UserNotifications**

At the top of the file, add:

```swift
import UserNotifications
```

**Step 2: Add temporary allow methods**

After the `removeRule` method (around line 440), add:

```swift
// MARK: - Temporary Allow

/// Start a temporary allow for a rule
func temporaryAllow(_ rule: ACLRule, minutes: Int) async {
    guard !togglingRuleIds.contains(rule.ruleId) else { return }

    togglingRuleIds.insert(rule.ruleId)
    defer { togglingRuleIds.remove(rule.ruleId) }

    // Store original state
    rule.temporaryAllowOriginalEnabled = rule.isEnabled
    rule.temporaryAllowExpiry = Date().addingTimeInterval(TimeInterval(minutes * 60))

    do {
        // Disable the rule to allow traffic
        try await api.toggleRule(ruleId: rule.ruleId, enabled: false)
        rule.isEnabled = false
        rule.lastSynced = Date()

        // Schedule notification
        if let expiry = rule.temporaryAllowExpiry {
            NotificationService.shared.scheduleTemporaryAllowExpiry(for: rule, at: expiry)
        }

        try? modelContext?.save()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        logger.info("Started temporary allow for \(rule.name) for \(minutes) minutes")
    } catch {
        // Rollback on failure
        rule.temporaryAllowExpiry = nil
        rule.temporaryAllowOriginalEnabled = nil
        logger.error("Failed to start temporary allow: \(error.localizedDescription)")
        errorMessage = "Couldn't allow temporarily. Try again."
    }
}

/// Extend an active temporary allow
func extendTemporaryAllow(_ rule: ACLRule, minutes: Int) async {
    guard rule.hasActiveTemporaryAllow else { return }

    let baseTime = max(Date(), rule.temporaryAllowExpiry ?? Date())
    rule.temporaryAllowExpiry = baseTime.addingTimeInterval(TimeInterval(minutes * 60))

    // Reschedule notification
    NotificationService.shared.cancelNotification(for: rule.ruleId)
    if let expiry = rule.temporaryAllowExpiry {
        NotificationService.shared.scheduleTemporaryAllowExpiry(for: rule, at: expiry)
    }

    try? modelContext?.save()

    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()

    logger.info("Extended temporary allow for \(rule.name) by \(minutes) minutes")
}

/// Cancel temporary allow and re-block
func cancelTemporaryAllow(_ rule: ACLRule) async {
    guard rule.temporaryAllowExpiry != nil else { return }

    togglingRuleIds.insert(rule.ruleId)
    defer { togglingRuleIds.remove(rule.ruleId) }

    await reblockAfterTemporaryAllow(rule)

    // Haptic feedback
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

/// Re-block a rule after temporary allow expires
private func reblockAfterTemporaryAllow(_ rule: ACLRule) async {
    let shouldEnable = rule.temporaryAllowOriginalEnabled ?? true

    // Clear temporary allow state
    rule.temporaryAllowExpiry = nil
    rule.temporaryAllowOriginalEnabled = nil

    // Cancel notification
    NotificationService.shared.cancelNotification(for: rule.ruleId)

    do {
        if shouldEnable {
            try await api.toggleRule(ruleId: rule.ruleId, enabled: true)
            rule.isEnabled = true
        }
        rule.lastSynced = Date()
        try? modelContext?.save()

        logger.info("Re-blocked \(rule.name) after temporary allow")
    } catch {
        // Keep expiry set so we retry on next app open
        rule.temporaryAllowExpiry = Date() // Mark as expired but needing retry
        logger.error("Failed to re-block after temporary allow: \(error.localizedDescription)")
        errorMessage = "Couldn't re-block \(rule.displayName). Tap to retry."
    }
}

/// Check for and handle expired temporary allows (call on app becoming active)
func checkExpiredTemporaryAllows() async {
    let now = Date()
    let expiredRules = rules.filter { rule in
        guard let expiry = rule.temporaryAllowExpiry else { return false }
        return expiry <= now
    }

    guard !expiredRules.isEmpty else { return }

    for rule in expiredRules {
        await reblockAfterTemporaryAllow(rule)
    }

    // Show toast (you can implement this with a published property)
    let count = expiredRules.count
    logger.info("Re-blocked \(count) rule(s) after temporary allow expired")
}
```

**Step 3: Commit**

```bash
git add SilenceTheLAN/ViewModels/AppState.swift
git commit -m "feat: add temporary allow methods to AppState"
```

---

### Task 5: Add Context Menu to ActivityRuleRow

**Files:**
- Modify: `SilenceTheLAN/Views/Dashboard/DashboardView.swift:410-486`

**Step 1: Update ActivityRuleRow to accept temporary allow callbacks**

Replace the `ActivityRuleRow` struct with:

```swift
struct ActivityRuleRow: View {
    @Bindable var rule: ACLRule
    let isToggling: Bool
    let onToggle: () -> Void
    let onTemporaryAllow: (Int) -> Void
    let onExtendTemporaryAllow: (Int) -> Void
    let onCancelTemporaryAllow: () -> Void

    private var stateColor: Color {
        if rule.hasActiveTemporaryAllow {
            return Color.theme.neonAmber
        }
        return rule.isCurrentlyBlocking ? Color.theme.neonRed : Color.theme.neonGreen
    }

    private var activityIcon: String {
        switch rule.activityName.lowercased() {
        case "internet": return "wifi"
        case "games": return "gamecontroller.fill"
        case "youtube": return "play.rectangle.fill"
        case "social": return "bubble.left.and.bubble.right.fill"
        case "streaming": return "tv.fill"
        default: return "app.fill"
        }
    }

    private var statusText: String {
        if let remaining = rule.temporaryAllowTimeRemainingFormatted {
            return "Allowed for \(remaining)"
        }
        return rule.isCurrentlyBlocking ? "BLOCKED" : "ALLOWED"
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Activity icon
                Image(systemName: activityIcon)
                    .font(.system(size: 14))
                    .foregroundColor(stateColor)
                    .frame(width: 24)

                // Activity name and status
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.activityName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text(rule.hasActiveTemporaryAllow ? statusText : rule.scheduleSummary)
                        .font(.system(size: 10))
                        .foregroundColor(rule.hasActiveTemporaryAllow ? stateColor : Color.theme.textTertiary)
                }

                Spacer()

                // Status indicator
                if isToggling {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: stateColor))
                        .scaleEffect(0.6)
                } else {
                    // Compact toggle
                    HStack(spacing: 6) {
                        if rule.hasActiveTemporaryAllow {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                        } else {
                            Circle()
                                .fill(stateColor)
                                .frame(width: 8, height: 8)
                        }

                        Text(statusText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(stateColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(stateColor.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.theme.background.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(stateColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
        .contextMenu {
            if rule.hasActiveTemporaryAllow {
                // Active temporary allow - show cancel/extend options
                Button(role: .destructive) {
                    onCancelTemporaryAllow()
                } label: {
                    Label("Cancel (re-block now)", systemImage: "xmark.circle")
                }

                Divider()

                Button { onExtendTemporaryAllow(15) } label: {
                    Label("Extend by 15 min", systemImage: "clock.badge.plus")
                }
                Button { onExtendTemporaryAllow(30) } label: {
                    Label("Extend by 30 min", systemImage: "clock.badge.plus")
                }
                Button { onExtendTemporaryAllow(60) } label: {
                    Label("Extend by 1 hour", systemImage: "clock.badge.plus")
                }
                Button { onExtendTemporaryAllow(120) } label: {
                    Label("Extend by 2 hours", systemImage: "clock.badge.plus")
                }
            } else if rule.isCurrentlyBlocking {
                // Currently blocking - show temporary allow options
                Button { onTemporaryAllow(15) } label: {
                    Label("Allow 15 min", systemImage: "clock")
                }
                Button { onTemporaryAllow(30) } label: {
                    Label("Allow 30 min", systemImage: "clock")
                }
                Button { onTemporaryAllow(60) } label: {
                    Label("Allow 1 hour", systemImage: "clock")
                }
                Button { onTemporaryAllow(120) } label: {
                    Label("Allow 2 hours", systemImage: "clock")
                }
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add SilenceTheLAN/Views/Dashboard/DashboardView.swift
git commit -m "feat: add context menu to ActivityRuleRow for temporary allow"
```

---

### Task 6: Update PersonGroupCard to Pass Callbacks

**Files:**
- Modify: `SilenceTheLAN/Views/Dashboard/DashboardView.swift:284-406`

**Step 1: Add callback properties to PersonGroupCard**

Update the `PersonGroupCard` struct properties to include:

```swift
struct PersonGroupCard: View {
    let group: RuleGroup
    let isExpanded: Bool
    let togglingRuleIds: Set<String>
    let onToggleExpand: () -> Void
    let onToggleAll: (Bool) -> Void
    let onToggleRule: (ACLRule) -> Void
    let onTemporaryAllow: (ACLRule, Int) -> Void
    let onExtendTemporaryAllow: (ACLRule, Int) -> Void
    let onCancelTemporaryAllow: (ACLRule) -> Void

    // ... rest of the struct stays the same until the ForEach
```

**Step 2: Update the ForEach inside PersonGroupCard**

Replace the ForEach loop (around line 377-384) with:

```swift
ForEach(group.rules) { rule in
    ActivityRuleRow(
        rule: rule,
        isToggling: togglingRuleIds.contains(rule.ruleId),
        onToggle: { onToggleRule(rule) },
        onTemporaryAllow: { minutes in onTemporaryAllow(rule, minutes) },
        onExtendTemporaryAllow: { minutes in onExtendTemporaryAllow(rule, minutes) },
        onCancelTemporaryAllow: { onCancelTemporaryAllow(rule) }
    )
}
```

**Step 3: Commit**

```bash
git add SilenceTheLAN/Views/Dashboard/DashboardView.swift
git commit -m "feat: update PersonGroupCard to pass temporary allow callbacks"
```

---

### Task 7: Update DashboardView to Wire Up Callbacks

**Files:**
- Modify: `SilenceTheLAN/Views/Dashboard/DashboardView.swift:66-91`

**Step 1: Update the PersonGroupCard instantiation**

Replace the PersonGroupCard instantiation in the ForEach (around line 67-91) with:

```swift
PersonGroupCard(
    group: group,
    isExpanded: expandedGroups.contains(group.id),
    togglingRuleIds: appState.togglingRuleIds,
    onToggleExpand: {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if expandedGroups.contains(group.id) {
                expandedGroups.remove(group.id)
            } else {
                expandedGroups.insert(group.id)
            }
        }
    },
    onToggleAll: { shouldBlock in
        Task {
            await appState.toggleAllRulesForPerson(group.rules, shouldBlock: shouldBlock)
        }
    },
    onToggleRule: { rule in
        Task {
            await appState.toggleRule(rule)
        }
    },
    onTemporaryAllow: { rule, minutes in
        Task {
            await appState.temporaryAllow(rule, minutes: minutes)
        }
    },
    onExtendTemporaryAllow: { rule, minutes in
        Task {
            await appState.extendTemporaryAllow(rule, minutes: minutes)
        }
    },
    onCancelTemporaryAllow: { rule in
        Task {
            await appState.cancelTemporaryAllow(rule)
        }
    }
)
```

**Step 2: Commit**

```bash
git add SilenceTheLAN/Views/Dashboard/DashboardView.swift
git commit -m "feat: wire up temporary allow callbacks in DashboardView"
```

---

### Task 8: Add Timer for Countdown Refresh

**Files:**
- Modify: `SilenceTheLAN/Views/Dashboard/DashboardView.swift:23-27`

**Step 1: Add timer state**

In `DashboardView`, add a timer state property after `expandedGroups`:

```swift
@State private var timerTick: Int = 0
```

**Step 2: Add timer modifier**

After the `.task` modifier (around line 118), add:

```swift
.onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
    // Trigger UI refresh for countdown timers
    timerTick += 1
}
```

**Step 3: Use timerTick to force refresh**

This ensures SwiftUI recalculates computed properties. The `timerTick` variable doesn't need to be used directly - its change triggers a view update which recalculates `temporaryAllowTimeRemainingFormatted`.

**Step 4: Commit**

```bash
git add SilenceTheLAN/Views/Dashboard/DashboardView.swift
git commit -m "feat: add timer to refresh temporary allow countdowns"
```

---

### Task 9: Handle App Lifecycle for Expired Checks

**Files:**
- Modify: `SilenceTheLAN/SilenceTheLANApp.swift`

**Step 1: Add scenePhase environment**

Update the app struct to observe scene phase:

```swift
@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    // ... sharedModelContainer stays the same ...

    init() {
        // Register App Shortcuts with Siri
        SilenceTheLANShortcuts.updateAppShortcutParameters()

        // Request notification permission
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        Task {
                            await appState.checkExpiredTemporaryAllows()
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**Step 2: Commit**

```bash
git add SilenceTheLAN/SilenceTheLANApp.swift
git commit -m "feat: check expired temporary allows when app becomes active"
```

---

### Task 10: Handle Notification Actions

**Files:**
- Modify: `SilenceTheLAN/ViewModels/AppState.swift`

**Step 1: Make AppState conform to UNUserNotificationCenterDelegate**

At the end of AppState.swift, add an extension:

```swift
// MARK: - Notification Handling

extension AppState: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let ruleId = userInfo["ruleId"] as? String else {
            completionHandler()
            return
        }

        Task { @MainActor in
            guard let rule = rules.first(where: { $0.ruleId == ruleId }) else {
                completionHandler()
                return
            }

            switch response.actionIdentifier {
            case "REBLOCK_NOW":
                await cancelTemporaryAllow(rule)
            case "EXTEND_15":
                await extendTemporaryAllow(rule, minutes: 15)
            case UNNotificationDefaultActionIdentifier:
                // User tapped notification body - check all expired
                await checkExpiredTemporaryAllows()
            default:
                break
            }

            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
```

**Step 2: Set delegate in AppState init or configure**

In the `configure(modelContext:)` method, add:

```swift
NotificationService.shared.setDelegate(self)
```

**Step 3: Commit**

```bash
git add SilenceTheLAN/ViewModels/AppState.swift
git commit -m "feat: handle notification actions for temporary allow"
```

---

### Task 11: Clear Temporary Allow on Manual Toggle

**Files:**
- Modify: `SilenceTheLAN/ViewModels/AppState.swift`

**Step 1: Update toggleRule to clear temporary allow state**

In the `toggleRule` method, near the beginning (after the guard statement), add:

```swift
// If rule has active temporary allow, clear it (user taking manual control)
if rule.temporaryAllowExpiry != nil {
    rule.temporaryAllowExpiry = nil
    rule.temporaryAllowOriginalEnabled = nil
    NotificationService.shared.cancelNotification(for: rule.ruleId)
}
```

**Step 2: Commit**

```bash
git add SilenceTheLAN/ViewModels/AppState.swift
git commit -m "feat: clear temporary allow state on manual toggle"
```

---

### Task 12: Build and Test

**Step 1: Build the project**

```bash
xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Step 2: Manual testing checklist**

1. Long-press a blocking rule → see 4 time options
2. Tap "Allow 15 min" → rule shows amber with countdown
3. Wait for notification → tap "Re-block Now" → rule re-blocks
4. Start temporary allow → close app → reopen after expiry → auto re-blocks
5. Start temporary allow → long-press → see "Extend by" options
6. Start temporary allow → tap rule normally → temporary allow cleared

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete temporary allow feature implementation"
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Add neonAmber color to theme |
| 2 | Add data model fields to ACLRule |
| 3 | Create NotificationService |
| 4 | Add temporary allow methods to AppState |
| 5 | Add context menu to ActivityRuleRow |
| 6 | Update PersonGroupCard to pass callbacks |
| 7 | Wire up callbacks in DashboardView |
| 8 | Add timer for countdown refresh |
| 9 | Handle app lifecycle for expired checks |
| 10 | Handle notification actions |
| 11 | Clear temporary allow on manual toggle |
| 12 | Build and test |
