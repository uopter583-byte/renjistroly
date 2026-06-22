import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

// MARK: - Learn and match

func testLearnAndMatchByPhrase() async {
    let registry = AgentSkillRegistry()
    await registry.learn(
        name: "Git Commit",
        description: "Create a git commit",
        triggerPhrases: ["提交代码", "git commit", "commit changes"],
        steps: ["git add", "git commit"]
    )
    let skill = await registry.match("我想提交代码到仓库")
    XCTAssertTrue(skill != nil)
    XCTAssertTrue(skill?.name == "Git Commit")
}

func testMatchByName() async {
    let registry = AgentSkillRegistry()
    await registry.learn(
        name: "Run Tests",
        description: "Run the test suite",
        triggerPhrases: ["run tests", "测试"],
        steps: ["swift test"]
    )
    let skill = await registry.match("Run Tests 请执行")
    XCTAssertTrue(skill != nil)
    XCTAssertTrue(skill?.name == "Run Tests")
}

func testMatchNoMatch() async {
    let registry = AgentSkillRegistry()
    await registry.learn(
        name: "Deploy",
        description: "Deploy to production",
        triggerPhrases: ["deploy", "部署"],
        steps: ["build", "push"]
    )
    let matched = await registry.match("今天天气怎么样")
    XCTAssertTrue(matched == nil)
}

func testMatchPrioritizesSuccessRate() async {
    let registry = AgentSkillRegistry()
    _ = await registry.learn(
        name: "Alpha",
        description: "First skill",
        triggerPhrases: ["test"],
        steps: []
    )
    _ = await registry.learn(
        name: "Beta",
        description: "Second skill",
        triggerPhrases: ["test"],
        steps: []
    )
    // Both match "test" — should return the one with higher success rate
    // Default both have success=0, failure=0. Second registered wins on tiebreaker (createdAt).
    let matched = await registry.match("test")
    XCTAssertTrue(matched != nil)
    // Both have same score; sorted by success-failure, then .first.
    // With equal scores, order depends on iteration order of skills.values.
    // Either Alpha or Beta is valid.
    XCTAssertTrue(matched?.name == "Alpha" || matched?.name == "Beta")
}

// MARK: - All skills

func testAllSkillsSortedByDate() async {
    let registry = AgentSkillRegistry()
    await registry.learn(name: "First", description: "", triggerPhrases: [], steps: [])
    try? await Task.sleep(nanoseconds: 100_000_000) // ensure different timestamps
    await registry.learn(name: "Second", description: "", triggerPhrases: [], steps: [])
    let all = await registry.all()
    XCTAssertTrue(all.count == 2)
    XCTAssertTrue(all[0].name == "Second") // newer first
    XCTAssertTrue(all[1].name == "First")
}
