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
        // Bug 36 Diagnostic: 4 CC-Buttons mit verschiedenen Mechanismen
        TestAControl()  // star.fill  - Pure openAppWhenRun
        TestBControl()  // flame.fill - App Group Flag + openAppWhenRun
        TestCControl()  // link       - OpenURLIntent + openAppWhenRun
        TestDControl()  // bolt.fill  - App Group Flag ohne openAppWhenRun

        // Home/Lock Screen Widget for quick task capture
        QuickCaptureWidget()

        // Live Activity for Focus Blocks
        FocusBlockLiveActivity()
    }
}
