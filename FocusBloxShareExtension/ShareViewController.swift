import UIKit
import SwiftUI
import SwiftData
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

        do {
            let schema = Schema([LocalTask.self, TaskMetadata.self])
            let config: ModelConfiguration

            // Try App Group + CloudKit first, fallback to App Group only
            if FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.henning.focusblox"
            ) != nil {
                config = ModelConfiguration(
                    schema: schema,
                    groupContainer: .identifier("group.com.henning.focusblox"),
                    cloudKitDatabase: .private("iCloud.com.henning.focusblox")
                )
            } else {
                config = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private("iCloud.com.henning.focusblox")
                )
            }

            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            let task = LocalTask(title: trimmedTitle)
            task.needsTitleImprovement = true
            task.sourceURL = sourceURL
            context.insert(task)
            try context.save()

            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            errorMessage = "Fehler beim Speichern: \(error.localizedDescription)"
        }
    }

    // MARK: - Cancel

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(domain: "com.henning.focusblox.share", code: 0)
        )
    }
}
