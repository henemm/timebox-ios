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
        // QuickAdd mit Intent aus FocusBloxCore Framework
        QuickAddTaskControl()

        // Live Activity for Focus Blocks
        FocusBlockLiveActivity()
    }
}
