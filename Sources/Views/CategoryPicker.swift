import SwiftUI

struct CategoryPicker: View {
    let currentCategory: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Kategorie")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TaskCategory.allCases, id: \.rawValue) { category in
                    Button {
                        onSelect(category.rawValue)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.title3)
                            Text(category.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentCategory == category.rawValue ? category.color : .gray)
                    .accessibilityIdentifier("category-\(category.rawValue)")
                }
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("category-picker")
        .presentationDetents([.height(220)])
    }
}
