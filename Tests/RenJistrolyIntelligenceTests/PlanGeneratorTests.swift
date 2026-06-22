import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - shouldPlan decisions (requires >= 30 chars)

final class PlanGeneratorTests: XCTestCase {
    func testShouldPlanEmptyText() async {
        let pg = PlanGenerator()
        let empty = await pg.shouldPlan("")
        XCTAssertTrue(empty == false)
        let spaces = await pg.shouldPlan("   ")
        XCTAssertTrue(spaces == false)
    }

    func testShouldPlanTooShort() async {
        let pg = PlanGenerator()
        let short = await pg.shouldPlan("你好世界 hello world test")
        XCTAssertTrue(short == false)
    }

    func testShouldPlanWithIndicator() async {
        let pg = PlanGenerator()
        // All >= 30 chars with a complexity indicator keyword
        let r1 = await pg.shouldPlan("请帮我分析这个文件的代码质量问题并找出所有性能瓶颈和安全漏洞")
        XCTAssertTrue(r1 == true)
        let r2 = await pg.shouldPlan("请帮我重构一下 AppDelegate 这个文件中的初始化逻辑和依赖注入方法")
        XCTAssertTrue(r2 == true)
        let r3 = await pg.shouldPlan("请修复登录页面崩溃的问题用户反馈频繁闪退需要紧急排查处理解决")
        XCTAssertTrue(r3 == true)
        let r4 = await pg.shouldPlan("请优化数据库查询性能减少首页加载时间并提升整体用户体验和响应速度")
        XCTAssertTrue(r4 == true)
        let r5 = await pg.shouldPlan("Please review this code for potential issues and bugs")
        XCTAssertTrue(r5 == true)
        let r6 = await pg.shouldPlan("refactor the auth module to use new API endpoints")
        XCTAssertTrue(r6 == true)
        let r7 = await pg.shouldPlan("implement user registration flow with email verification")
        XCTAssertTrue(r7 == true)
        let r8 = await pg.shouldPlan("deploy to production after running all tests successfully")
        XCTAssertTrue(r8 == true)
    }

    func testShouldPlanLongWithMultiIntent() async {
        let pg = PlanGenerator()
        let text = "请帮我检查这个登录 bug 并且修复它然后再运行完整的测试套件"
        let result = await pg.shouldPlan(text)
        XCTAssertTrue(result == true)
    }

    func testShouldPlanVeryLongText() async {
        let pg = PlanGenerator()
        let text = String(repeating: "A", count: 151)
        let result = await pg.shouldPlan(text)
        XCTAssertTrue(result == true)
    }

    func testShouldPlanPlainQuestion() async {
        let pg = PlanGenerator()
        let result = await pg.shouldPlan("这个函数是做什么用的呢我想了解一下")
        XCTAssertTrue(result == false)
    }

    // MARK: - parseSteps (requires step desc >= 4 chars)

    func testParseStepsNumberedList() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "1. 读取当前文件内容\n2. 分析代码结构设计\n3. 提出改进优化建议")
        guard steps.count == 3 else { XCTFail("Expected 3 steps, got \(steps.count)"); return }
        XCTAssertTrue(steps[0].description == "读取当前文件内容")
        XCTAssertTrue(steps[1].description == "分析代码结构设计")
        XCTAssertTrue(steps[2].description == "提出改进优化建议")
    }

    func testParseStepsChineseNumbering() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "1、检查登录逻辑代码\n2、修复验证问题缺陷\n3、运行测试套件")
        guard steps.count == 3 else { XCTFail("Expected 3 steps, got \(steps.count)"); return }
        XCTAssertTrue(steps[0].description == "检查登录逻辑代码")
    }

    func testParseStepsBulletList() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "- 第一步准备工作\n- 第二步执行核心\n- 第三步收尾验证")
        guard steps.count == 3 else { XCTFail("Expected 3 steps, got \(steps.count)"); return }
        XCTAssertTrue(steps[0].description == "第一步准备工作")
    }

    func testParseStepsMixedFormat() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "1. 检查配置文件\n• 修改参数设置\n* 验证结果输出")
        guard steps.count == 3 else { XCTFail("Expected 3 steps, got \(steps.count)"); return }
        XCTAssertTrue(!steps[0].description.isEmpty)
    }

    func testParseStepsEmptyText() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "")
        XCTAssertTrue(steps.isEmpty)
    }

    func testParseStepsTooShortLines() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "1. ab\n2. cd")
        XCTAssertTrue(steps.isEmpty)
    }

    func testParseStepsTooLongLines() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "1. " + String(repeating: "很长的步骤描述文字", count: 23))
        XCTAssertTrue(steps.isEmpty)
    }

    func testParseStepsWhitespaceOnly() async {
        let pg = PlanGenerator()
        let steps = await pg.parseSteps(from: "1.   \n2.   \n")
        XCTAssertTrue(steps.isEmpty)
    }

    // MARK: - generateTitle

    func testGenerateTitleShort() async {
        let pg = PlanGenerator()
        let title = await pg.generateTitle(from: "修复登录 bug")
        XCTAssertTrue(title == "修复登录 bug")
    }

    func testGenerateTitleLong() async {
        let pg = PlanGenerator()
        let long = String(repeating: "很长的标题", count: 20)
        let title = await pg.generateTitle(from: long)
        XCTAssertTrue(title.count <= 41)
        XCTAssertTrue(title.hasSuffix("…"))
    }

    func testGenerateTitleExactly40() async {
        let pg = PlanGenerator()
        let text = String(repeating: "A", count: 40)
        let title = await pg.generateTitle(from: text)
        XCTAssertTrue(title == text)
    }

    func testGenerateTitleWhitespace() async {
        let pg = PlanGenerator()
        let title = await pg.generateTitle(from: "  简洁标题  ")
        XCTAssertTrue(title == "简洁标题")
    }
}
