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
