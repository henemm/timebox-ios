import SwiftUI
import SwiftData

/// Reusable tag input with chips and autocomplete suggestions.
/// Works on both iOS and macOS.
struct TagInputView: View {
    @Binding var tags: [String]
    @Environment(\.modelContext) private var modelContext

    @State private var newTag = ""
    @State private var allUsedTags: [String] = []

    private var suggestions: [String] {
        let available = allUsedTags.filter { !tags.contains($0) }
        if newTag.isEmpty { return Array(available.prefix(5)) }
        return available.filter { $0.localizedCaseInsensitiveContains(newTag) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current tags as chips
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }

            // Input field
            HStack {
                TextField("Neuer Tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("tagInput")
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .onSubmit { addCurrentTag() }

                Button { addCurrentTag() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("addTagButton")
            }

            // Suggestions
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                if !tags.contains(suggestion) {
                                    tags.append(suggestion)
                                    newTag = ""
                                }
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tagSuggestion_\(suggestion)")
                        }
                    }
                }
            }
        }
        .onAppear { loadUsedTags() }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
            Button {
                tags.removeAll { $0 == tag }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("removeTag_\(tag)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        #if os(iOS)
        .background(Capsule().fill(Color(.secondarySystemFill)))
        #else
        .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
        #endif
    }

    private func addCurrentTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }

    private func loadUsedTags() {
        let taskSource = LocalTaskSource(modelContext: modelContext)
        allUsedTags = (try? taskSource.fetchAllUsedTags()) ?? []
    }
}

// MARK: - Flow Layout (shared between iOS and macOS)

/// Layout that wraps items to the next line when they exceed the available width
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        let totalWidth = maxWidth == .infinity ? currentX : maxWidth
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

