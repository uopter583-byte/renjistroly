import Foundation
import RenJistrolyModels

public actor WorkflowTemplateStore {
    private var templates: [WorkflowTemplate] = []
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        self.templates = Self.loadSynchronously(from: self.storageURL)
    }

    public var allTemplates: [WorkflowTemplate] {
        templates.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }

    public func templates(for appName: String) -> [WorkflowTemplate] {
        allTemplates.filter { $0.appName?.localizedCaseInsensitiveContains(appName) == true }
    }

    public func templates(withTag tag: String) -> [WorkflowTemplate] {
        allTemplates.filter { $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(tag) }) }
    }

    public func template(id: UUID) -> WorkflowTemplate? {
        templates.first { $0.id == id }
    }

    public func save(_ template: WorkflowTemplate) async {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.append(template)
        }
        await persist()
    }

    public func recordUse(id: UUID) async {
        guard let idx = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[idx].useCount += 1
        templates[idx].lastUsedAt = Date()
        await persist()
    }

    public func delete(id: UUID) async {
        templates.removeAll { $0.id == id }
        await persist()
    }

    public func createFromRun(
        name: String,
        appName: String?,
        steps: [ComputerUseStepResult],
        description: String = "",
        tags: [String] = []
    ) -> WorkflowTemplate {
        let templateSteps = steps.map { step in
            WorkflowTemplate.TemplateStep(
                toolName: step.action.toolCall.name,
                arguments: step.action.toolCall.arguments,
                expectedVerification: step.verificationEvidence.first
            )
        }
        return WorkflowTemplate(
            name: name,
            description: description,
            appName: appName,
            steps: templateSteps,
            tags: tags
        )
    }

    // MARK: - Persistence

    private func persist() async {
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Non-critical: templates persist on next successful save
        }
    }

    private static func loadSynchronously(from url: URL) -> [WorkflowTemplate] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WorkflowTemplate].self, from: data)) ?? []
    }

    public static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("RenJistroly")
            .appendingPathComponent("workflow-templates.json")
    }
}
