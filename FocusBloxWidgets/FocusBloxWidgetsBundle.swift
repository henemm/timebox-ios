//
//  FocusBloxWidgetsBundle.swift
//  FocusBloxWidgets
//
//  Created by Henning Emmrich on 20.01.26.
//

import WidgetKit
import SwiftUI

@main
struct FocusBloxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Control Center: Quick Task Button
        QuickAddTaskControl()

        // Home/Lock Screen Widget for quick task capture
        QuickCaptureWidget()

        // Live Activity for Focus Blocks
        FocusBlockLiveActivity()
    }
}
