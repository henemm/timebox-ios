import SwiftUI

// MARK: - Day Phase

enum DayPhase: Equatable {
    case morning
    case daytime
    case evening

    /// Determines the current phase from a given hour and settings.
    /// - Parameters:
    ///   - hour: Hour of day (0-23)
    ///   - morningEnd: Hour when morning ends (exclusive)
    ///   - eveningStart: Hour when evening starts (inclusive)
    static func from(hour: Int, morningEnd: Int, eveningStart: Int) -> DayPhase {
        if hour < morningEnd { return .morning }
        if hour < eveningStart { return .daytime }
        return .evening
    }
}

// MARK: - Day View

struct DayView: View {
    @AppStorage("morningEndHour") private var morningEndHour = 12
    @AppStorage("eveningStartHour") private var eveningStartHour = 18

    private var phase: DayPhase {
        let hour = Calendar.current.component(.hour, from: Date())
        return DayPhase.from(hour: hour, morningEnd: morningEndHour, eveningStart: eveningStartHour)
    }

    var body: some View {
        NavigationStack {
            phaseContent
                .navigationTitle(navigationTitle)
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .morning:
            ContentUnavailableView(
                "Guten Morgen",
                systemImage: "sunrise",
                description: Text("Kalender-Uebersicht kommt bald")
            )
        case .daytime:
            ContentUnavailableView(
                "Dein Tag",
                systemImage: "sun.max",
                description: Text("Timeline kommt bald")
            )
        case .evening:
            ContentUnavailableView(
                "Tagesrueckblick",
                systemImage: "moon.stars",
                description: Text("Reflexion kommt bald")
            )
        }
    }

    private var navigationTitle: String {
        switch phase {
        case .morning: return "Guten Morgen"
        case .daytime: return "Dein Tag"
        case .evening: return "Tagesrueckblick"
        }
    }
}
