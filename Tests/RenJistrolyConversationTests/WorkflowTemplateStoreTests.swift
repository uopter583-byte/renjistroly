import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

// MARK: - WorkflowTemplateStore tests

func testEmptyStore() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-empty-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)
    let all = await store.allTemplates
    XCTAssertTrue(all.isEmpty)
}

func testSaveAndRetrieve() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-save-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    let template = WorkflowTemplate(name: "Test", steps: [
        .init(toolName: "click", arguments: ["x": "10"]),
    ])
    await store.save(template)

    let all = await store.allTemplates
    XCTAssertTrue(all.count == 1)
    XCTAssertTrue(all[0].name == "Test")
}

func testUpdateExistingTemplate() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-update-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    var template = WorkflowTemplate(name: "Original")
    await store.save(template)

    template.name = "Updated"
    await store.save(template)

    let all = await store.allTemplates
    XCTAssertTrue(all.count == 1)
    XCTAssertTrue(all[0].name == "Updated")
}

func testDeleteTemplate() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-delete-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    let template = WorkflowTemplate(name: "ToDelete")
    await store.save(template)
    let count = await store.allTemplates.count
    XCTAssertTrue(count == 1)

    await store.delete(id: template.id)
    let deleted = await store.allTemplates.isEmpty
    XCTAssertTrue(deleted)
}

func testRecordUse() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-recorduse-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    let template = WorkflowTemplate(name: "Frequent")
    await store.save(template)
    await store.recordUse(id: template.id)

    let all = await store.allTemplates
    XCTAssertTrue(all[0].useCount == 1)
    XCTAssertTrue(all[0].lastUsedAt != nil)
}

func testRecordUseOnNonExistentIsNoop() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-noop-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)
    await store.recordUse(id: UUID())
    // Should not crash
}

func testFilterByAppName() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-filterapp-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    await store.save(WorkflowTemplate(name: "Safari Search", appName: "Safari"))
    await store.save(WorkflowTemplate(name: "Safari Tab", appName: "Safari"))
    await store.save(WorkflowTemplate(name: "Finder Nav", appName: "Finder"))

    let safariTemplates = await store.templates(for: "Safari")
    XCTAssertTrue(safariTemplates.count == 2)
    let finderTemplates = await store.templates(for: "Finder")
    XCTAssertTrue(finderTemplates.count == 1)
}

func testFilterByTag() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-filtertag-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    await store.save(WorkflowTemplate(name: "ABC", tags: ["browser", "search"]))
    await store.save(WorkflowTemplate(name: "XYZ", tags: ["browser", "dev"]))

    let browserTemplates = await store.templates(withTag: "browser")
    XCTAssertTrue(browserTemplates.count == 2)
    let searchTemplates = await store.templates(withTag: "search")
    XCTAssertTrue(searchTemplates.count == 1)
    let devTemplates = await store.templates(withTag: "dev")
    XCTAssertTrue(devTemplates.count == 1)
}

func testTemplateByID() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-byid-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    let t1 = WorkflowTemplate(name: "Alpha")
    let t2 = WorkflowTemplate(name: "Beta")
    await store.save(t1)
    await store.save(t2)

    let found = await store.template(id: t1.id)
    XCTAssertTrue(found?.name == "Alpha")
}

func testCreateFromRun() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-fromrun-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    let toolResult = ToolCallResult(id: "s1", output: "done")
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "s1", name: "click", arguments: ["x": "100", "y": "200"])
    )
    let steps: [ComputerUseStepResult] = [
        ComputerUseStepResult(
            action: action,
            beforeState: nil,
            toolResult: toolResult,
            afterState: nil,
            verified: true,
            verificationEvidence: ["clicked"]
        ),
    ]

    let template = await store.createFromRun(
        name: "Learned Action",
        appName: "Finder",
        steps: steps,
        description: "From run",
        tags: ["learned"]
    )

    XCTAssertTrue(template.name == "Learned Action")
    XCTAssertTrue(template.appName == "Finder")
    XCTAssertTrue(template.actionCount == 1)
    XCTAssertTrue(template.tags == ["learned"])
}

func testSortByLastUsed() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-sort-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = WorkflowTemplateStore(storageURL: url)

    let t1 = WorkflowTemplate(name: "Old")
    let t2 = WorkflowTemplate(name: "New")

    await store.save(t1)
    await store.save(t2)
    await store.recordUse(id: t2.id)

    let all = await store.allTemplates
    // Most recently used should be first
    XCTAssertTrue(all.first?.name == "New")
}
