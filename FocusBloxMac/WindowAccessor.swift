//
//  WindowAccessor.swift
//  FocusBloxMac
//
//  Fix for SwiftUI macOS windows not receiving keyboard/mouse events.
//  The problem: NSWindow.canBecomeKeyWindow returns NO, so window can't receive events.
//  Solution: Access the window and configure it to accept key status.
//
//  See: https://github.com/onmyway133/blog/issues/789
//

import SwiftUI
import AppKit

// MARK: - Window Accessor

/// Provides access to the underlying NSWindow in SwiftUI
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Configure window to accept key and main status
                configureWindow(window)
                self.callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configureWindow(window)
            }
        }
    }

    private func configureWindow(_ window: NSWindow) {
        // Make window key and main so it receives events
        window.makeKeyAndOrderFront(nil)
        window.makeMain()

        // Ensure window accepts mouse events
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        // Activate the app
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

// MARK: - View Extension

extension View {
    /// Ensures the window can become key and receive all events
    func enableWindowEvents() -> some View {
        self.background(
            WindowAccessor { window in
                // Window is now configured
            }
        )
    }
}

// MARK: - Key Window Modifier

/// Alternative approach: Force window to become key on appear
struct KeyWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                        window.makeMain()
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                }
            }
            .background(
                WindowAccessor { _ in }
            )
    }
}

extension View {
    func makeKeyWindow() -> some View {
        self.modifier(KeyWindowModifier())
    }
}
