//
//  ClickThroughView.swift
//  FocusBloxMac
//
//  Workaround for macOS SwiftUI windows not responding to clicks.
//  See: https://christiantietze.de/posts/2024/04/enable-swiftui-button-click-through-inactive-windows/
//

import SwiftUI
import AppKit

// MARK: - Click-Through NSView

/// NSView that accepts first mouse events, enabling click-through on inactive windows
final class ClickAcceptingView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - NSViewRepresentable Wrapper

/// Wraps content in a view that accepts first mouse events
struct ClickThroughWrapper<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = AcceptingHostingView(rootView: content)
        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

/// NSHostingView that accepts first mouse events
final class AcceptingHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - View Extension

extension View {
    /// Enable the view to receive "first mouse" events on inactive windows.
    /// Apply this to fix click-through issues on macOS.
    func acceptClickThrough() -> some View {
        background(
            ClickThroughBackdrop()
        )
    }
}

/// Invisible backdrop that accepts first mouse events
struct ClickThroughBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> ClickAcceptingView {
        let view = ClickAcceptingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: ClickAcceptingView, context: Context) {}
}
