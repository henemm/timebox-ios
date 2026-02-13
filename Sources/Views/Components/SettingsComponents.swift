import SwiftUI
import EventKit

/// Shared calendar row for Settings views (iOS + macOS).
/// Replaces CalendarRow and MacCalendarRow (BACKLOG-011).
struct CalendarRow: View {
    let calendar: EKCalendar

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 12, height: 12)
            Text(calendar.title)
        }
    }
}

/// Shared reminder list row for Settings views (iOS + macOS).
/// Replaces ReminderListRow and MacReminderListRow (BACKLOG-011).
struct ReminderListRow: View {
    let list: ReminderListInfo

    var body: some View {
        HStack(spacing: 8) {
            if let hex = list.colorHex {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 12, height: 12)
            }
            Text(list.title)
        }
    }
}

/// Generic Set membership binding.
/// Replaces calendarBinding/binding and reminderListBinding in both Settings views.
func setMembershipBinding(for id: String, in set: Binding<Set<String>>) -> Binding<Bool> {
    Binding(
        get: { set.wrappedValue.contains(id) },
        set: { isVisible in
            if isVisible {
                set.wrappedValue.insert(id)
            } else {
                set.wrappedValue.remove(id)
            }
        }
    )
}
