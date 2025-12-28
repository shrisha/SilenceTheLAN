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

        // Note: Activity shortcuts (BlockActivityIntent, AllowActivityIntent) are available
        // through the Shortcuts app but not via direct Siri phrases, as App Shortcuts
        // only support single-parameter phrases. Users can create custom Siri shortcuts
        // in the Shortcuts app for specific activity rules.
    }
}
