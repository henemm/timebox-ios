import SwiftUI

struct SuccessStoryView: View {
    let completedTasks: [PlanItem]
    let focusBlocks: [FocusBlock]

    @State private var story: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Erstelle Erfolgs-Story...")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("successStoryLoadingView")
            } else if let story {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Deine Erfolgs-Story", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.headline)
                    Text(story)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("successStoryCard")
            }
        }
        .task {
            let result = await SuccessStoryService.generate(
                completedTasks: completedTasks,
                focusBlocks: focusBlocks
            )
            story = result
            isLoading = false
        }
    }
}
