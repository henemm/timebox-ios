import SwiftUI

/// Shared category icon badge for calendar event blocks.
/// Shows the category-specific SF Symbol in a small colored circle.
/// Used as `.overlay(alignment: .topTrailing)` on both iOS and macOS.
struct CategoryIconBadge: View {
    let category: TaskCategory

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(category.color)
            )
    }
}
