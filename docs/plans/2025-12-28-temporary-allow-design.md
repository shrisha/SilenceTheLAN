# Temporary Allow Feature Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:writing-plans to create implementation plan from this design.

**Goal:** Allow users to temporarily unblock a rule for a set duration (15m, 30m, 1h, 2h), with automatic re-blocking when time expires.

**Context:** Community feedback requested "give me 30 more mins, please" functionality. This can be accomplished client-side only (no server component) using local notifications and on-app-open checks.

---

## Data Model

Add two fields to `ACLRule`:

```swift
var temporaryAllowExpiry: Date?           // When temp allow expires (nil = not active)
var temporaryAllowOriginalEnabled: Bool?  // Was rule enabled before temp allow?
```

**State logic:**
- `temporaryAllowExpiry == nil` → No temporary allow active
- `temporaryAllowExpiry != nil && expiry > now` → Active, show countdown
- `temporaryAllowExpiry != nil && expiry <= now` → Expired, needs re-blocking

Existing `originalScheduleStart/End` fields remain unchanged.

---

## User Flow: Initiating Temporary Allow

1. User long-presses a rule that's currently blocking
2. Context menu shows: "Allow 15 min", "Allow 30 min", "Allow 1 hour", "Allow 2 hours"
3. User taps an option
4. App:
   - Sets `temporaryAllowExpiry = Date() + selectedDuration`
   - Sets `temporaryAllowOriginalEnabled = rule.isEnabled`
   - Disables rule in UniFi (`isEnabled = false`)
   - Schedules local notification for expiry time
   - Shows haptic + visual confirmation

**Context menu conditions:**
- Only shows when `rule.isCurrentlyBlocking == true`
- Only shows when `rule.temporaryAllowExpiry == nil`

---

## User Flow: Extending Temporary Allow

When temporary allow is already active, long-press shows:
- "Cancel (re-block now)"
- "Extend by 15 min"
- "Extend by 30 min"
- "Extend by 1 hour"
- "Extend by 2 hours"

**Extension calculation:**
```swift
let baseTime = max(Date(), rule.temporaryAllowExpiry ?? Date())
rule.temporaryAllowExpiry = baseTime + TimeInterval(minutes * 60)
```

This preserves remaining time when extending early.

---

## Notifications

**Scheduling:**
- Notification ID: `"temp-allow-\(rule.ruleId)"`
- Title: "Time's up"
- Body: "\(rule.displayName)'s internet access is ending"
- Scheduled for `temporaryAllowExpiry`

**Notification actions (UNNotificationCategory):**
- "Re-block Now" → Immediately re-blocks
- "Extend 15 min" → Extends and reschedules notification

**When user taps notification body:**
- Opens app
- App checks for expired temporary allows on `sceneDidBecomeActive`
- Auto re-blocks and shows toast

**Canceling:**
- Manual cancel → Remove pending notification
- Extend → Remove old, schedule new

---

## Dashboard UI

**Visual state for active temporary allow:**
- Status color: Amber/yellow (distinct from red/green)
- Status text: "Allowed for 23 min" or "Allowed for 1h 30m"

**Display logic:**
```swift
if let expiry = rule.temporaryAllowExpiry, expiry > Date() {
    statusColor = Color.theme.neonYellow
    statusText = "Allowed for \(timeRemaining(until: expiry))"
} else if rule.isCurrentlyBlocking {
    statusColor = Color.theme.neonRed
    statusText = rule.scheduleSummary
} else {
    statusColor = Color.theme.neonGreen
    statusText = rule.scheduleSummary
}
```

**Time formatting:**
- Under 1 hour: "23 min"
- 1 hour or more: "1h 30m"

**Refresh:** Timer fires every 60 seconds while app is in foreground.

---

## Re-blocking Logic

**On `sceneDidBecomeActive`:**

```swift
func checkExpiredTemporaryAllows() async {
    let now = Date()
    let expiredRules = rules.filter { rule in
        guard let expiry = rule.temporaryAllowExpiry else { return false }
        return expiry <= now
    }

    for rule in expiredRules {
        await reblockAfterTemporaryAllow(rule)
    }

    if !expiredRules.isEmpty {
        showToast("Re-blocked \(expiredRules.count) rule(s)")
    }
}
```

**Re-block implementation:**

```swift
func reblockAfterTemporaryAllow(_ rule: ACLRule) async {
    let shouldEnable = rule.temporaryAllowOriginalEnabled ?? true

    rule.temporaryAllowExpiry = nil
    rule.temporaryAllowOriginalEnabled = nil

    if shouldEnable {
        try await api.toggleRule(ruleId: rule.ruleId, enabled: true)
        rule.isEnabled = true
    }

    removeNotification(for: rule.ruleId)
    rule.lastSynced = Date()
}
```

---

## Edge Cases

**API failure on initiate:**
- Don't set expiry or schedule notification
- Show error, rule stays blocking

**API failure on re-block:**
- Keep expiry set (retry on next app open)
- Show warning state on rule row

**Manual toggle during temporary allow:**
- Clear expiry and original state
- Cancel notification
- User takes manual control

**App deleted during temporary allow:**
- Local data lost, rule stays disabled in UniFi
- User must manually re-enable
- Acceptable trade-off for no server component

**Multiple concurrent temporary allows:**
- Each rule tracks independently
- Multiple notifications scheduled
- Re-block handles all expired rules in one pass

---

## Summary

| Decision | Choice |
|----------|--------|
| Re-blocking trigger | Local notification + on-app-open fallback |
| UniFi rule during allow | Disabled (`isEnabled = false`) |
| UI to initiate | Long-press context menu |
| Time options | 15m, 30m, 1h, 2h |
| Extension calculation | `max(now, currentExpiry) + duration` |
| Expired handling | Auto re-block on app open |
