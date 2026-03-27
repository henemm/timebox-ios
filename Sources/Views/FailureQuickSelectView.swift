import SwiftUI
import SwiftData

struct FailureQuickSelectView: View {
    let task: PlanItem
    @Environment(\.modelContext) private var modelContext
    @State private var selectedReason: FailureReason?
    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        dismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("failureDismiss_\(task.id)")
                }

                Text("Woran lag's?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(FailureReason.allCases, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                            FailureProtocolService.save(
                                taskID: task.id,
                                reason: reason,
                                context: modelContext
                            )
                        } label: {
                            Label(reason.displayName, systemImage: reason.systemImage)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedReason == reason
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(.systemFill),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("failureReason_\(reason.rawValue)")
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("failureQuickSelect_\(task.id)")
        }
    }
}
