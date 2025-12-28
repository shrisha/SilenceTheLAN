# Siri Intents Design for SilenceTheLAN

## Overview

Add Siri voice control to SilenceTheLAN, allowing parents to block/allow internet access for family members using voice commands.

## Supported Commands

### Person-Level Commands
Block or allow all rules for a person:

| Action | Phrases |
|--------|---------|
| Block | "Block [person]", "Turn off [person]'s internet", "Silence [person]" |
| Allow | "Allow [person]", "Turn on [person]'s internet", "Unsilence [person]" |

Examples:
- "Block Rishi in SilenceTheLAN" → blocks all of Rishi's rules (Internet, Games, YouTube, etc.)
- "Allow Emma in SilenceTheLAN" → allows all of Emma's rules

### Activity-Level Commands
Block or allow a specific activity for a person:

| Action | Phrases |
|--------|---------|
| Block | "Block [person]'s [activity]" |
| Allow | "Allow [person]'s [activity]" |

Examples:
- "Block Rishi's gaming in SilenceTheLAN" → blocks only Rishi's gaming rule
- "Allow Emma's YouTube in SilenceTheLAN" → allows only Emma's YouTube rule

## Technical Approach

### Framework: App Intents (iOS 16+)

Using the modern App Intents framework because:
- Native Siri and Shortcuts integration
- Supports dynamic parameters (person names, activities)
- Simpler than legacy SiriKit
- App already targets iOS 17+

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                         Siri                            │
└─────────────────────────┬───────────────────────────────┘
                          │ Voice Command
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    App Intents                          │
│  ┌──────────────────┐  ┌──────────────────────────────┐ │
│  │  PersonEntity    │  │  BlockPersonIntent           │ │
│  │  ActivityEntity  │  │  AllowPersonIntent           │ │
│  │                  │  │  BlockActivityIntent         │ │
│  │  (Parameters)    │  │  AllowActivityIntent         │ │
│  └──────────────────┘  └──────────────────────────────┘ │
└─────────────────────────┬───────────────────────────────┘
                          │ Delegates to
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    AppState                             │
│  toggleAllRulesForPerson()  │  toggleRule()            │
└─────────────────────────┬───────────────────────────────┘
                          │ API Calls
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  UniFi Controller                       │
└─────────────────────────────────────────────────────────┘
```

## File Structure

```
SilenceTheLAN/
├── Intents/
│   ├── Entities/
│   │   ├── PersonEntity.swift      # Person parameter for Siri
│   │   └── ActivityEntity.swift    # Activity parameter for Siri
│   ├── Intents/
│   │   ├── BlockPersonIntent.swift
│   │   ├── AllowPersonIntent.swift
│   │   ├── BlockActivityIntent.swift
│   │   └── AllowActivityIntent.swift
│   └── AppShortcuts.swift          # Registers phrase patterns
```

## Implementation Details

### PersonEntity

Represents a person (e.g., "Rishi") extracted from rule names.

```swift
struct PersonEntity: AppEntity {
    var id: String          // Lowercase identifier, e.g., "rishi"
    var displayName: String // Display name, e.g., "Rishi"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Person"
    static var defaultQuery = PersonEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
}

struct PersonEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PersonEntity] {
        // Fetch from SwiftData, match by id
    }

    func suggestedEntities() async throws -> [PersonEntity] {
        // Return all unique person names from cached rules
    }
}
```

### ActivityEntity

Represents a specific activity rule (e.g., "Rishi's Games").

```swift
struct ActivityEntity: AppEntity {
    var id: String           // e.g., "rishi-games"
    var personName: String   // e.g., "Rishi"
    var activityName: String // e.g., "Games"
    var ruleId: String       // UniFi rule ID for direct access

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static var defaultQuery = ActivityEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(activityName)")
    }
}
```

### BlockPersonIntent

```swift
struct BlockPersonIntent: AppIntent {
    static var title: LocalizedStringResource = "Block Person"
    static var description = IntentDescription("Block all internet access for a person")

    @Parameter(title: "Person")
    var person: PersonEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Check network
        guard NetworkMonitor.shared.isUniFiReachable else {
            return .result(dialog: "Sorry, you need to be on your home network to control this")
        }

        // 2. Get rules for person
        let container = try ModelContainer(for: ACLRule.self, AppConfiguration.self)
        let context = ModelContext(container)
        let personId = person.id.lowercased()
        let descriptor = FetchDescriptor<ACLRule>(
            predicate: #Predicate { $0.isSelected }
        )
        let allRules = try context.fetch(descriptor)
        let rules = allRules.filter { $0.personName.lowercased() == personId }

        guard !rules.isEmpty else {
            return .result(dialog: "I couldn't find anyone named \(person.displayName) in your rules")
        }

        // 3. Block all rules
        await AppState.shared.toggleAllRulesForPerson(rules, shouldBlock: true)

        // 4. Return summary
        let activities = rules.map { $0.activityName }.joined(separator: ", ")
        return .result(dialog: "Blocked \(person.displayName). \(rules.count) rules affected: \(activities)")
    }
}
```

### AppShortcuts Registration

```swift
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

## Error Handling

| Scenario | Siri Response |
|----------|---------------|
| Off home network | "Sorry, you need to be on your home network to control this" |
| Person not found | "I couldn't find anyone named [name] in your rules" |
| Activity not found | "I couldn't find [activity] for [person]" |
| API failure | "Couldn't reach UniFi controller. Try again later" |
| No rules configured | "No rules are set up yet. Open SilenceTheLAN to configure" |

## Changes to Existing Code

### AppState.swift

Add static shared instance for intent access:

```swift
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // ... existing code
}
```

### SilenceTheLANApp.swift

Register App Shortcuts provider:

```swift
@main
struct SilenceTheLANApp: App {
    init() {
        // Register shortcuts
        SilenceTheLANShortcuts.updateAppShortcutParameters()
    }

    // ... existing code
}
```

## Testing Plan

1. **Unit tests** for entity queries (mock SwiftData)
2. **Manual Siri testing** on device:
   - Test each phrase variant
   - Test off-network behavior
   - Test with no rules configured
   - Test case insensitivity ("RISHI" vs "Rishi")
3. **Shortcuts app testing** - verify intents appear and work

## Future Considerations

- **Widgets**: Could reuse entity/intent structure for home screen widgets
- **Apple Watch**: App Intents work on watchOS with minimal changes
- **Focus modes**: Could auto-block during certain Focus modes
