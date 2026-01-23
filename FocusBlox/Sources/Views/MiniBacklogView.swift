import SwiftUI

struct MiniBacklogView: View {
    let tasks: [PlanItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tasks) { task in
                    MiniTaskCard(task: task)
                        .draggable(PlanItemTransfer(from: task))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
}
