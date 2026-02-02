//
//  MinimalTestApp.swift
//  Test file to isolate the click problem
//
//  Run with: swift MinimalTestApp.swift
//

import SwiftUI

// MINIMAL TEST: Does a basic SwiftUI macOS app work?
// If this works but our app doesn't, the problem is in our code.
// If this also doesn't work, the problem is system-level.

struct MinimalContentView: View {
    @State private var text = ""
    @State private var clickCount = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Minimal Test App")
                .font(.title)

            Text("Click count: \(clickCount)")

            Button("Click Me") {
                clickCount += 1
                print("Button clicked! Count: \(clickCount)")
            }
            .buttonStyle(.borderedProminent)

            TextField("Type here...", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            Text("You typed: \(text)")
        }
        .padding(40)
        .frame(width: 400, height: 300)
    }
}

// To test: Create a new Xcode project with ONLY this code
// No MenuBarExtra, no SwiftData, no nothing else.
