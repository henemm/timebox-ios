//
//  TimeBoxWidgetsBundle.swift
//  TimeBoxWidgets
//
//  Created by Henning Emmrich on 20.01.26.
//

import WidgetKit
import SwiftUI

@main
struct TimeBoxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // QuickAdd mit Intent aus TimeBoxCore Framework
        QuickAddTaskControl()
    }
}
