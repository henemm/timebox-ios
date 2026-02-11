import AppIntents

/// SnippetIntent that renders the interactive Quick Capture view in Siri/Spotlight.
/// iOS 26 Interactive Snippet pattern: returns a SwiftUI view with Button(intent:) controls.
struct CreateTaskSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Quick Capture Snippet"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Titel")
    var taskTitle: String

    @Dependency var captureState: QuickCaptureState

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        return .result(view: QuickCaptureSnippetView(
            title: taskTitle,
            state: captureState
        ))
    }
}

extension CreateTaskSnippetIntent {
    init(taskTitle: String) {
        self.taskTitle = taskTitle
    }
}
