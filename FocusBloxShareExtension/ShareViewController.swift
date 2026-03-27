import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ShareViewController

/// Hosts the SwiftUI share sheet inside the Share Extension.
/// Extracts text/URL from the share context and lets the user save a new task.
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(
            rootView: ShareSheetView(
                extensionContext: extensionContext
            )
        )

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }
}

// MARK: - SwiftUI Share Sheet

struct ShareSheetView: View {
    let extensionContext: NSExtensionContext?

    @State private var taskTitle = ""
    @State private var sourceURL: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Inhalt wird geladen...")
                } else {
                    TextField("Task-Titel", text: $taskTitle, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Neuer Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveTask()
                    }
                    .fontWeight(.semibold)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await extractSharedContent()
        }
    }

    // MARK: - Content Extraction

    private func extractSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            taskTitle = ""
            isLoading = false
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            // Try URL first (Safari shares URLs)
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let result = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                       let url = result as? URL {
                        sourceURL = url.absoluteString
                        let title = item.attributedContentText?.string
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if let title, !title.isEmpty {
                            taskTitle = String(title.prefix(500))
                        } else {
                            taskTitle = String(url.absoluteString.prefix(500))
                        }
                        isLoading = false
                        return
                    }
                }
            }

            // Try plain text
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let result = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let text = result as? String {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            taskTitle = String(trimmed.prefix(500))
                        }
                        isLoading = false
                        return
                    }
                }
            }
        }

        taskTitle = ""
        isLoading = false
    }

    // MARK: - Save

    private func saveTask() {
        let trimmedTitle = String(
            taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)
        )
        guard !trimmedTitle.isEmpty else { return }

        // Save via App Group UserDefaults — main app picks up on next launch
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        var pending = defaults?.array(forKey: "pendingSharedTasks") as? [[String: String]] ?? []
        var entry: [String: String] = [
            "title": trimmedTitle,
            "id": UUID().uuidString,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let sourceURL {
            entry["sourceURL"] = sourceURL
        }
        pending.append(entry)
        defaults?.set(pending, forKey: "pendingSharedTasks")

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - Cancel

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(domain: "com.henning.focusblox.share", code: 0)
        )
    }
}
