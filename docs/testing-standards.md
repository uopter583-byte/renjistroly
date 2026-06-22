# 测试规范

## 框架选择

本项目统一使用 **XCTest** 框架。

- 禁止使用 `import Testing`（Swift Testing 框架）
- 测试文件必须使用 `import XCTest`
- 测试类必须继承 `XCTestCase`

## 测试方法命名

```
func test[模块]_[场景]()
```

示例：

```swift
func testProviderRouter_selectableCasesExcludesCloudRealtime()
func testShellExecutor_emptyCommand_throwsError()
```

## 测试文件结构

```swift
import XCTest
@testable import 目标模块

final class 类名Tests: XCTestCase {
    func test模块_场景() {
        // given
        // when
        // then
    }
}
```

## 测试 tag 规则

| Tag | 用途 | 运行方式 |
|-----|------|---------|
| 无 tag | 单元测试 | `swift test` |
| `manual` | 需要手动环境 | `swift test --filter 测试名` |
| `longrunning` | 长时间运行 | CI 中独立 job |
| `security` | 安全测试 | CI 安全扫描阶段 |
| `performance` | 性能基准 | 按需运行 |

在 Package.swift 中使用 `swiftSettings: [.enableUpcomingFeature("InternalImportsByDefault")]` 按需配置。

## 断言规范

| Testing 语法 | XCTest 等价写法 |
|-------------|----------------|
| `#expect(expr)` | `XCTAssertTrue(expr)` |
| `#expect(!expr)` | `XCTAssertFalse(expr)` |
| `#expect(a == b)` | `XCTAssertEqual(a, b)` |
| `#expect(a != b)` | `XCTAssertNotEqual(a, b)` |
| `#expect(a == nil)` | `XCTAssertNil(a)` |
| `#expect(a != nil)` | `XCTAssertNotNil(a)` |
| `#expect(Bool(false), "msg")` | `XCTFail("msg")` |
| `#expect(throws: ...)` | `XCTAssertThrowsError(...)` |
| `#expect(noThrow: ...)` | `XCTAssertNoThrow(...)` |

## @testable import

- 使用 `@testable import 模块名` 访问 internal 类型
- 不要在非测试文件中使用 `@testable`

## 测试文件位置

每个测试文件必须放在对应的 Test target 目录下：

```
Tests/<TargetName>Tests/
├── <File1>Tests.swift
└── <File2>Tests.swift
```

目录名必须与 Package.swift 中的 `testTarget(name:)` 一致。

## 常见错误

1. **混用 Testing 和 XCTest** — 编译报错：删除 `import Testing`，改为 `import XCTest`
2. **缺少 XCTestCase 类包裹** — `@Test func` 需要包装在 `final class XxxTests: XCTestCase {}` 内
3. **`#expect` 宏** — 必须全部替换为 `XCTAssert*` 系列断言
4. **缺少 `@testable import`** — XCTest 不能直接测试 internal 类型
