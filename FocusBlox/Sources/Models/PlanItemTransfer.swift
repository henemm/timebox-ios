import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let planItem = UTType(exportedAs: "com.henning.timebox.planitem")
}

struct PlanItemTransfer: Codable, Transferable, Sendable {
    let id: String
    let title: String
    let duration: Int

    init(from item: PlanItem) {
        self.id = item.id
        self.title = item.title
        self.duration = item.effectiveDuration
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .planItem)
    }
}
