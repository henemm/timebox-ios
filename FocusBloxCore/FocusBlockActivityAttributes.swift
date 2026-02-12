//
//  FocusBlockActivityAttributes.swift
//  FocusBloxCore
//
//  Created for Sprint 4: Live Activity
//

import ActivityKit
import Foundation

/// ActivityKit attributes for Focus Block Live Activity
/// Used for Lock Screen and Dynamic Island display
/// Shared between main app and widget extension via FocusBloxCore framework
public struct FocusBlockActivityAttributes: ActivityAttributes {
    /// Static data - doesn't change during activity
    public let blockTitle: String
    public let startDate: Date
    public let endDate: Date
    public let totalTaskCount: Int

    /// Dynamic data - can be updated during activity
    public struct ContentState: Codable, Hashable {
        public let currentTaskTitle: String?
        public let completedCount: Int
        public let taskEndDate: Date?

        public init(currentTaskTitle: String?, completedCount: Int, taskEndDate: Date? = nil) {
            self.currentTaskTitle = currentTaskTitle
            self.completedCount = completedCount
            self.taskEndDate = taskEndDate
        }
    }

    public init(blockTitle: String, startDate: Date, endDate: Date, totalTaskCount: Int) {
        self.blockTitle = blockTitle
        self.startDate = startDate
        self.endDate = endDate
        self.totalTaskCount = totalTaskCount
    }
}

// MARK: - Preview Helpers

#if DEBUG
public extension FocusBlockActivityAttributes {
    static var preview: FocusBlockActivityAttributes {
        FocusBlockActivityAttributes(
            blockTitle: "Focus Block",
            startDate: Date(),
            endDate: Date().addingTimeInterval(25 * 60),
            totalTaskCount: 3
        )
    }
}

public extension FocusBlockActivityAttributes.ContentState {
    static var sample: FocusBlockActivityAttributes.ContentState {
        FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: "Code Review",
            completedCount: 1,
            taskEndDate: Date().addingTimeInterval(15 * 60)
        )
    }
}
#endif
