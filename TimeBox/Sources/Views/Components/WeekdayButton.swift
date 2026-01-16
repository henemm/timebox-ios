import SwiftUI

/// Weekday toggle button for recurrence selection
struct WeekdayButton: View {
    let weekday: Weekday
    @Binding var selectedWeekdays: Set<Int>

    private var isSelected: Bool {
        selectedWeekdays.contains(weekday.value)
    }

    var body: some View {
        Button {
            if isSelected {
                selectedWeekdays.remove(weekday.value)
            } else {
                selectedWeekdays.insert(weekday.value)
            }
        } label: {
            Text(weekday.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

/// Weekday representation for recurrence
struct Weekday: Identifiable {
    let value: Int  // 1=Mon, 2=Tue, ..., 7=Sun
    let shortName: String
    let fullName: String

    var id: Int { value }

    static let monday = Weekday(value: 1, shortName: "Mo", fullName: "Montag")
    static let tuesday = Weekday(value: 2, shortName: "Di", fullName: "Dienstag")
    static let wednesday = Weekday(value: 3, shortName: "Mi", fullName: "Mittwoch")
    static let thursday = Weekday(value: 4, shortName: "Do", fullName: "Donnerstag")
    static let friday = Weekday(value: 5, shortName: "Fr", fullName: "Freitag")
    static let saturday = Weekday(value: 6, shortName: "Sa", fullName: "Samstag")
    static let sunday = Weekday(value: 7, shortName: "So", fullName: "Sonntag")

    static let all: [Weekday] = [
        monday, tuesday, wednesday, thursday, friday, saturday, sunday
    ]
}

#Preview {
    @Previewable @State var selectedWeekdays: Set<Int> = [1, 3, 5]

    VStack(spacing: 16) {
        Text("Selected: \(selectedWeekdays.sorted().map(String.init).joined(separator: ", "))")

        HStack(spacing: 8) {
            ForEach(Weekday.all) { weekday in
                WeekdayButton(weekday: weekday, selectedWeekdays: $selectedWeekdays)
            }
        }
    }
    .padding()
}
