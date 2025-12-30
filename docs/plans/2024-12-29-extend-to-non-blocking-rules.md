# Extend Temporary Allow to Non-Blocking Rules Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow temporary extensions on both currently blocking AND not-blocking rules, with appropriate UI labels.

**Architecture:** Remove the `isCurrentlyBlocking` restriction from the context menu. The existing `temporaryAllow()` logic already works correctly—it pauses the rule, which prevents blocking (whether now or in the future). Update UI labels to reflect the different use cases: "Allow for..." when blocking, "Delay block by..." when not blocking.

**Tech Stack:** SwiftUI, existing AppState methods

---

## Task 1: Update Context Menu to Support Non-Blocking Rules

**Files:**
- Modify: `SilenceTheLAN/Views/Dashboard/DashboardView.swift:530-568`

**Step 1: Remove blocking-only restriction**

Current code (line 553):
```swift
} else if rule.isCurrentlyBlocking {
    // Currently blocking - show temporary allow options
```

Change to:
```swift
} else {
    // Show temporary allow/delay options based on current state
```

**Step 2: Add context-aware labels**

Replace the hardcoded "Allow X min" labels with dynamic labels based on `rule.isCurrentlyBlocking`:

```swift
} else {
    // Show temporary allow/delay options based on current state
    let labelPrefix = rule.isCurrentlyBlocking ? "Allow" : "Delay block by"

    Button { onTemporaryAllow(15) } label: {
        Label("\(labelPrefix) 15 min", systemImage: "clock")
    }
    Button { onTemporaryAllow(30) } label: {
        Label("\(labelPrefix) 30 min", systemImage: "clock")
    }
    Button { onTemporaryAllow(60) } label: {
        Label("\(labelPrefix) 1 hour", systemImage: "clock")
    }
    Button { onTemporaryAllow(120) } label: {
        Label("\(labelPrefix) 2 hours", systemImage: "clock")
    }
}
```

**Step 3: Build and verify no compilation errors**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Views/Dashboard/DashboardView.swift
git commit -m "feat: allow temporary extensions on non-blocking rules

- Remove isCurrentlyBlocking restriction from context menu
- Add dynamic labels: 'Allow' vs 'Delay block by'
- Backend logic already supports this (pauses rule preemptively)"
```

---

## Task 2: Manual Testing

**Test Case 1: Blocking rule extension (existing behavior)**

**Setup:**
- Rule: "Downtime-Rishi" with schedule 10pm-7am
- Time: 11pm (inside schedule, rule is blocking)

**Steps:**
1. Long-press the rule
2. Verify context menu shows: "Allow 15 min", "Allow 30 min", etc.
3. Select "Allow 30 min"
4. Verify rule shows countdown and "Paused" state
5. Wait for expiry or cancel
6. Verify rule re-enables

**Expected:** Same behavior as before ✅

**Test Case 2: Non-blocking rule extension (new behavior)**

**Setup:**
- Rule: "Downtime-Rishi" with schedule 10pm-7am
- Time: 9:45pm (outside schedule, rule is NOT blocking)

**Steps:**
1. Long-press the rule
2. Verify context menu shows: "Delay block by 15 min", "Delay block by 30 min", etc.
3. Select "Delay block by 30 min"
4. Verify rule shows countdown and "Paused" state
5. Wait until 10pm (normal schedule start time)
6. Verify rule stays NOT blocking (still paused)
7. Wait until 10:30pm (extension expiry)
8. Verify notification fires
9. Verify rule now starts blocking

**Expected:** Rule doesn't start blocking at scheduled time, waits until extension expires ✅

**Test Case 3: Edge case - extending already paused rule**

**Setup:**
- Rule is manually paused (not blocking)
- Time: Outside schedule

**Steps:**
1. Long-press the rule
2. Select "Delay block by 15 min"
3. Verify new expiry time replaces existing pause state

**Expected:** New expiry time set, notification scheduled ✅

---

## Task 3: Update README Documentation

**Files:**
- Modify: `README.md:34-40`

**Step 1: Update the Time Extensions section**

Current text:
```markdown
### Time Extensions

Need to let your kid finish a YouTube video? Long-press any rule to grant temporary access. The rule automatically re-enables when time expires, and you'll get a notification.
```

Change to:
```markdown
### Time Extensions

Long-press any rule for temporary exceptions:

- **Currently blocking?** "Allow for X minutes" - traffic flows, then auto-reblocks
- **Not yet blocking?** "Delay block by X minutes" - schedule start time is postponed

Perfect for "Can I have 30 more minutes before bedtime?" scenarios. You'll get a notification when the extension expires.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update time extensions to include non-blocking rules"
```

---

## Verification Checklist

- [ ] Context menu appears on both blocking and non-blocking rules
- [ ] Labels change based on rule state ("Allow" vs "Delay block by")
- [ ] Extensions on blocking rules work as before (allow traffic)
- [ ] Extensions on non-blocking rules prevent schedule from starting
- [ ] Notifications fire correctly for both cases
- [ ] Expired extensions re-enable blocking at the right time
- [ ] README updated with new functionality

---

## Notes

**Why this works:**

The existing `temporaryAllow()` implementation already does exactly what we need:
1. Pauses the rule (`enabled=false`)
2. Stores expiry time
3. Schedules notification
4. On expiry, unpauses the rule (`enabled=true`)

For blocking rules: Pause stops blocking immediately.
For non-blocking rules: Pause prevents blocking from starting when schedule begins.

**No backend changes needed** - this is purely a UI enablement!
