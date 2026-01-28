import AppIntents

/// Registers suggested shortcuts with Siri phrases for the Shortcuts app.
struct FocusBloxShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Erstelle Task in \(.applicationName)",
                "Neuer Task in \(.applicationName)",
                "Task erstellen in \(.applicationName)"
            ],
            shortTitle: "Task erstellen",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: GetNextUpIntent(),
            phrases: [
                "Was steht an in \(.applicationName)",
                "Next Up in \(.applicationName)",
                "Zeige Tasks in \(.applicationName)"
            ],
            shortTitle: "Next Up",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Markiere als erledigt in \(.applicationName)",
                "Task erledigen in \(.applicationName)"
            ],
            shortTitle: "Task erledigen",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: CountOpenTasksIntent(),
            phrases: [
                "Wie viele Tasks in \(.applicationName)",
                "Offene Tasks in \(.applicationName)"
            ],
            shortTitle: "Offene Tasks",
            systemImageName: "number"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
