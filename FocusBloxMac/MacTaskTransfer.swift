//
//  MacTaskTransfer.swift
//  FocusBloxMac
//
//  Created by Henning Emmrich on 31.01.26.
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let macTask = UTType(exportedAs: "com.henning.timebox.mactask")
}

/// Transferable struct for drag & drop of tasks from Next Up to Timeline
struct MacTaskTransfer: Codable, Transferable, Sendable {
    let id: String
    let title: String
    let duration: Int

    init(from task: LocalTask) {
        self.id = task.id
        self.title = task.title
        self.duration = task.estimatedDuration ?? 30
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .macTask)
    }
}
