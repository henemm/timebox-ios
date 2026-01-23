import SwiftUI

/// ViewModifier that adds a settings gear button to the toolbar
/// Apply with .withSettingsToolbar() on any view with a NavigationStack
struct SettingsToolbarModifier: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}

extension View {
    /// Adds a settings gear button to the navigation toolbar
    func withSettingsToolbar() -> some View {
        modifier(SettingsToolbarModifier())
    }
}
