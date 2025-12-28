# Siri Intents Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Siri voice control to block/allow internet access for family members using App Intents.

**Architecture:** App Intents with PersonEntity and ActivityEntity parameters that query SwiftData for available rules. Intents delegate to existing AppState methods for toggle logic.

**Tech Stack:** App Intents (iOS 16+), SwiftData, Swift Concurrency

---

## Task 1: Add Shared AppState Instance

**Files:**
- Modify: `SilenceTheLAN/ViewModels/AppState.swift:10-11`
- Modify: `SilenceTheLAN/SilenceTheLANApp.swift:6`

**Step 1: Add static shared instance to AppState**

In `AppState.swift`, add a static shared instance after line 10:

```swift
@MainActor
final class AppState: ObservableObject {
    // Shared instance for Siri Intents access
    static let shared = AppState()

    // MARK: - Published State
    // ... rest of existing code
```

**Step 2: Update SilenceTheLANApp to use shared instance**

In `SilenceTheLANApp.swift`, change line 6 from:
```swift
@StateObject private var appState = AppState()
```
to:
```swift
@StateObject private var appState = AppState.shared
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/ViewModels/AppState.swift SilenceTheLAN/SilenceTheLANApp.swift
git commit -m "feat: add shared AppState instance for Siri Intents"
```

---

## Task 2: Create Intents Directory Structure

**Files:**
- Create: `SilenceTheLAN/Intents/` directory
- Create: `SilenceTheLAN/Intents/Entities/` directory

**Step 1: Create directory structure**

```bash
mkdir -p SilenceTheLAN/Intents/Entities
```

**Step 2: Commit**

```bash
git add -A
git commit -m "chore: create Intents directory structure"
```

---

## Task 3: Implement PersonEntity

**Files:**
- Create: `SilenceTheLAN/Intents/Entities/PersonEntity.swift`

**Step 1: Create PersonEntity with EntityQuery**

Create `SilenceTheLAN/Intents/Entities/PersonEntity.swift`:

```swift
import AppIntents
import SwiftData

struct PersonEntity: AppEntity {
    var id: String
    var displayName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Person"
    static var defaultQuery = PersonEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

struct PersonEntityQuery: EntityQuery {
    func entities(for identifiers: [PersonEntity.ID]) async throws -> [PersonEntity] {
        let allPersons = try await suggestedEntities()
        return allPersons.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PersonEntity] {
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let rules = try context.fetch(descriptor)

        // Extract unique person names
        var seenNames = Set<String>()
        var persons: [PersonEntity] = []

        for rule in rules {
            let personName = rule.personName
            let normalizedId = personName.lowercased()

            if !seenNames.contains(normalizedId) {
                seenNames.insert(normalizedId)
                persons.append(PersonEntity(id: normalizedId, displayName: personName))
            }
        }

        return persons.sorted { $0.displayName < $1.displayName }
    }
}

extension PersonEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [PersonEntity] {
        let allPersons = try await suggestedEntities()
        let lowercased = string.lowercased()
        return allPersons.filter { $0.displayName.lowercased().contains(lowercased) }
    }
}
```

**Step 2: Add file to Xcode project**

Open Xcode and add `PersonEntity.swift` to the SilenceTheLAN target under the Intents/Entities group.

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Intents/Entities/PersonEntity.swift
git commit -m "feat: add PersonEntity for Siri person parameter"
```

---

## Task 4: Implement ActivityEntity

**Files:**
- Create: `SilenceTheLAN/Intents/Entities/ActivityEntity.swift`

**Step 1: Create ActivityEntity with EntityQuery**

Create `SilenceTheLAN/Intents/Entities/ActivityEntity.swift`:

```swift
import AppIntents
import SwiftData

struct ActivityEntity: AppEntity {
    var id: String
    var personName: String
    var activityName: String
    var ruleId: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static var defaultQuery = ActivityEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(activityName)")
    }

    init(id: String, personName: String, activityName: String, ruleId: String) {
        self.id = id
        self.personName = personName
        self.activityName = activityName
        self.ruleId = ruleId
    }
}

struct ActivityEntityQuery: EntityQuery {
    func entities(for identifiers: [ActivityEntity.ID]) async throws -> [ActivityEntity] {
        let allActivities = try await suggestedEntities()
        return allActivities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ActivityEntity] {
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let rules = try context.fetch(descriptor)

        return rules.map { rule in
            let id = "\(rule.personName.lowercased())-\(rule.activityName.lowercased())"
            return ActivityEntity(
                id: id,
                personName: rule.personName,
                activityName: rule.activityName,
                ruleId: rule.ruleId
            )
        }.sorted { $0.activityName < $1.activityName }
    }
}

extension ActivityEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ActivityEntity] {
        let allActivities = try await suggestedEntities()
        let lowercased = string.lowercased()
        return allActivities.filter {
            $0.activityName.lowercased().contains(lowercased) ||
            $0.personName.lowercased().contains(lowercased)
        }
    }
}
```

**Step 2: Add file to Xcode project**

Open Xcode and add `ActivityEntity.swift` to the SilenceTheLAN target under the Intents/Entities group.

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Intents/Entities/ActivityEntity.swift
git commit -m "feat: add ActivityEntity for Siri activity parameter"
```

---

## Task 5: Implement BlockPersonIntent

**Files:**
- Create: `SilenceTheLAN/Intents/BlockPersonIntent.swift`

**Step 1: Create BlockPersonIntent**

Create `SilenceTheLAN/Intents/BlockPersonIntent.swift`:

```swift
import AppIntents
import SwiftData

struct BlockPersonIntent: AppIntent {
    static var title: LocalizedStringResource = "Block Person"
    static var description = IntentDescription("Block all internet access for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Check network reachability
        guard NetworkMonitor.shared.isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        // 2. Get rules for this person
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let allRules = try context.fetch(descriptor)
        let personId = person.id.lowercased()
        let rules = allRules.filter { $0.personName.lowercased() == personId }

        guard !rules.isEmpty else {
            return .result(dialog: "I couldn't find anyone named \(person.displayName) in your rules")
        }

        // 3. Ensure AppState is configured
        let appState = AppState.shared
        if appState.rules.isEmpty {
            appState.configure(modelContext: context)
        }

        // 4. Block all rules for this person
        await appState.toggleAllRulesForPerson(rules, shouldBlock: true)

        // 5. Return summary
        let activities = rules.map { $0.activityName }.joined(separator: ", ")
        return .result(dialog: "Blocked \(person.displayName). \(rules.count) rules affected: \(activities)")
    }
}
```

**Step 2: Add file to Xcode project**

Open Xcode and add `BlockPersonIntent.swift` to the SilenceTheLAN target under the Intents group.

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Intents/BlockPersonIntent.swift
git commit -m "feat: add BlockPersonIntent for Siri"
```

---

## Task 6: Implement AllowPersonIntent

**Files:**
- Create: `SilenceTheLAN/Intents/AllowPersonIntent.swift`

**Step 1: Create AllowPersonIntent**

Create `SilenceTheLAN/Intents/AllowPersonIntent.swift`:

```swift
import AppIntents
import SwiftData

struct AllowPersonIntent: AppIntent {
    static var title: LocalizedStringResource = "Allow Person"
    static var description = IntentDescription("Allow all internet access for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Check network reachability
        guard NetworkMonitor.shared.isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        // 2. Get rules for this person
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let allRules = try context.fetch(descriptor)
        let personId = person.id.lowercased()
        let rules = allRules.filter { $0.personName.lowercased() == personId }

        guard !rules.isEmpty else {
            return .result(dialog: "I couldn't find anyone named \(person.displayName) in your rules")
        }

        // 3. Ensure AppState is configured
        let appState = AppState.shared
        if appState.rules.isEmpty {
            appState.configure(modelContext: context)
        }

        // 4. Allow all rules for this person
        await appState.toggleAllRulesForPerson(rules, shouldBlock: false)

        // 5. Return summary
        let activities = rules.map { $0.activityName }.joined(separator: ", ")
        return .result(dialog: "Allowed \(person.displayName). \(rules.count) rules affected: \(activities)")
    }
}
```

**Step 2: Add file to Xcode project**

Open Xcode and add `AllowPersonIntent.swift` to the SilenceTheLAN target under the Intents group.

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Intents/AllowPersonIntent.swift
git commit -m "feat: add AllowPersonIntent for Siri"
```

---

## Task 7: Implement BlockActivityIntent

**Files:**
- Create: `SilenceTheLAN/Intents/BlockActivityIntent.swift`

**Step 1: Create BlockActivityIntent**

Create `SilenceTheLAN/Intents/BlockActivityIntent.swift`:

```swift
import AppIntents
import SwiftData

struct BlockActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Block Activity"
    static var description = IntentDescription("Block a specific activity for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    @Parameter(title: "Activity")
    var activity: ActivityEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Check network reachability
        guard NetworkMonitor.shared.isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        // 2. Find the specific rule
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let ruleId = activity.ruleId
        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.ruleId == ruleId && $0.isSelected }
        )

        guard let rule = try context.fetch(descriptor).first else {
            return .result(dialog: "I couldn't find \(activity.activityName) for \(person.displayName)")
        }

        // 3. Ensure AppState is configured
        let appState = AppState.shared
        if appState.rules.isEmpty {
            appState.configure(modelContext: context)
        }

        // 4. Block this specific rule (if not already blocking)
        if !rule.isCurrentlyBlocking {
            await appState.toggleRule(rule)
        }

        // 5. Return confirmation
        return .result(dialog: "Blocked \(person.displayName)'s \(activity.activityName)")
    }
}
```

**Step 2: Add file to Xcode project**

Open Xcode and add `BlockActivityIntent.swift` to the SilenceTheLAN target under the Intents group.

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Intents/BlockActivityIntent.swift
git commit -m "feat: add BlockActivityIntent for Siri"
```

---

## Task 8: Implement AllowActivityIntent

**Files:**
- Create: `SilenceTheLAN/Intents/AllowActivityIntent.swift`

**Step 1: Create AllowActivityIntent**

Create `SilenceTheLAN/Intents/AllowActivityIntent.swift`:

```swift
import AppIntents
import SwiftData

struct AllowActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Allow Activity"
    static var description = IntentDescription("Allow a specific activity for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    @Parameter(title: "Activity")
    var activity: ActivityEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Check network reachability
        guard NetworkMonitor.shared.isReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        // 2. Find the specific rule
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)

        let ruleId = activity.ruleId
        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.ruleId == ruleId && $0.isSelected }
        )

        guard let rule = try context.fetch(descriptor).first else {
            return .result(dialog: "I couldn't find \(activity.activityName) for \(person.displayName)")
        }

        // 3. Ensure AppState is configured
        let appState = AppState.shared
        if appState.rules.isEmpty {
            appState.configure(modelContext: context)
        }

        // 4. Allow this specific rule (if currently blocking)
        if rule.isCurrentlyBlocking {
            await appState.toggleRule(rule)
        }

        // 5. Return confirmation
        return .result(dialog: "Allowed \(person.displayName)'s \(activity.activityName)")
    }
}
```

**Step 2: Add file to Xcode project**

Open Xcode and add `AllowActivityIntent.swift` to the SilenceTheLAN target under the Intents group.

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Intents/AllowActivityIntent.swift
git commit -m "feat: add AllowActivityIntent for Siri"
```

---

## Task 9: Create AppShortcuts Provider

**Files:**
- Create: `SilenceTheLAN/Intents/AppShortcuts.swift`

**Step 1: Create AppShortcuts provider**

Create `SilenceTheLAN/Intents/AppShortcuts.swift`:

```swift
import AppIntents

struct SilenceTheLANShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BlockPersonIntent(),
            phrases: [
                "Block \(\.$person) in \(.applicationName)",
                "Turn off \(\.$person)'s internet in \(.applicationName)",
                "Silence \(\.$person) in \(.applicationName)"
            ],
            shortTitle: "Block Person",
            systemImageName: "hand.raised.fill"
        )

        AppShortcut(
            intent: AllowPersonIntent(),
            phrases: [
                "Allow \(\.$person) in \(.applicationName)",
                "Turn on \(\.$person)'s internet in \(.applicationName)",
                "Unsilence \(\.$person) in \(.applicationName)"
            ],
            shortTitle: "Allow Person",
            systemImageName: "hand.thumbsup.fill"
        )

        AppShortcut(
            intent: BlockActivityIntent(),
            phrases: [
                "Block \(\.$person)'s \(\.$activity) in \(.applicationName)"
            ],
            shortTitle: "Block Activity",
            systemImageName: "xmark.circle.fill"
        )

        AppShortcut(
            intent: AllowActivityIntent(),
            phrases: [
                "Allow \(\.$person)'s \(\.$activity) in \(.applicationName)"
            ],
            shortTitle: "Allow Activity",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
```

**Step 2: Add file to Xcode project**

Open Xcode and add `AppShortcuts.swift` to the SilenceTheLAN target under the Intents group.

**Step 3: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SilenceTheLAN/Intents/AppShortcuts.swift
git commit -m "feat: add AppShortcuts provider for Siri phrases"
```

---

## Task 10: Register Shortcuts in App

**Files:**
- Modify: `SilenceTheLAN/SilenceTheLANApp.swift`

**Step 1: Add init to register shortcuts**

Modify `SilenceTheLANApp.swift` to add an init method:

```swift
import SwiftUI
import SwiftData

@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppConfiguration.self,
            ACLRule.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Register App Shortcuts with Siri
        SilenceTheLANShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme SilenceTheLAN -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SilenceTheLAN/SilenceTheLANApp.swift
git commit -m "feat: register App Shortcuts on app launch"
```

---

## Task 11: Add Files to Xcode Project

**Files:**
- Modify: `SilenceTheLAN.xcodeproj/project.pbxproj`

**Step 1: Open Xcode and add all Intent files**

Open the project in Xcode:
```bash
open SilenceTheLAN.xcodeproj
```

In Xcode:
1. Right-click on the SilenceTheLAN folder in the navigator
2. Select "New Group" and name it "Intents"
3. Inside Intents, create another group "Entities"
4. Drag the following files into their respective groups:
   - `Intents/Entities/PersonEntity.swift`
   - `Intents/Entities/ActivityEntity.swift`
   - `Intents/BlockPersonIntent.swift`
   - `Intents/AllowPersonIntent.swift`
   - `Intents/BlockActivityIntent.swift`
   - `Intents/AllowActivityIntent.swift`
   - `Intents/AppShortcuts.swift`
5. Ensure each file has the SilenceTheLAN target checked

**Step 2: Build and verify**

Run: Cmd+B in Xcode
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: add Intent files to Xcode project"
```

---

## Task 12: Test on Device

**Prerequisites:** Physical iPhone on same network as UniFi controller, with rules already configured in the app.

**Step 1: Install on device**

1. Connect iPhone to Mac
2. Select your device in Xcode
3. Run (Cmd+R)

**Step 2: Test Shortcuts app**

1. Open Shortcuts app on iPhone
2. Tap "+" to create new shortcut
3. Search for "SilenceTheLAN"
4. Verify all 4 shortcuts appear:
   - Block Person
   - Allow Person
   - Block Activity
   - Allow Activity
5. Add "Block Person" and select a person from your rules
6. Run the shortcut
7. Verify the rule is blocked in the SilenceTheLAN app

**Step 3: Test Siri**

1. Say "Hey Siri, Block [person name] in SilenceTheLAN"
2. Verify Siri responds with the status summary
3. Say "Hey Siri, Allow [person name] in SilenceTheLAN"
4. Verify the rule is allowed

**Step 4: Test off-network error**

1. Disconnect from home WiFi
2. Say "Hey Siri, Block [person] in SilenceTheLAN"
3. Verify Siri says "Sorry, you need to be on your home network to control this"

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete Siri Intents integration"
```

---

## Summary

After completing all tasks, you will have:

- 7 new files in `SilenceTheLAN/Intents/`
- Modified `AppState.swift` with shared instance
- Modified `SilenceTheLANApp.swift` with shortcuts registration
- Full Siri integration with 8 phrase patterns
- Graceful error handling for off-network scenarios
