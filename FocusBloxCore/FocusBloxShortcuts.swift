import AppIntents

// WICHTIG: Dieser Provider registriert die Intents beim System!
// Ohne ihn sind Intents in Frameworks für Control Center "unsichtbar".

public struct FocusBloxShortcuts: AppShortcutsProvider {

    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddTaskIntent(),
            phrases: [
                "Erstelle einen Task in \(.applicationName)",
                "Neuer Task in \(.applicationName)"
            ],
            shortTitle: "Schneller Task",
            systemImageName: "plus.circle"
        )
    }

    // Farbe für besseres Debugging im System
    public static var shortcutTileColor: ShortcutTileColor = .blue
}
