import SwiftUI

/// Shared category icon badge for calendar event blocks.
/// Shows the category-specific SF Symbol with a short label in a colored capsule.
/// Used as `.overlay(alignment: .topTrailing)` on both iOS and macOS.
struct CategoryIconBadge: View {
    let category: TaskCategory

    /// The displayed label text (localized category name).
    var labelText: String { category.localizedName }

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: category.icon)
                .font(.system(size: 11, weight: .bold))
            Text(labelText)
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(category.color)
        )
    }
}
