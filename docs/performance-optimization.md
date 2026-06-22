# 性能优化分析报告

## 1. ContextProvider.swift — 10 维上下文捕获串联瓶颈

- **当前复杂度**: O(10 * T)，其中 T 为单个上下文捕获耗时（支持 10s 超时），最坏理论延迟 100s
- **瓶颈**: `ContextManager.refresh()` 中 10 个 `await withTimeout(...)` 严格**串联执行**，即使各自内部用了 `withTaskGroup` 实现超时，外层依然是顺序等待前一个完成才开始下一个。`cachedComponents` 字典（line 295）声明了缓存机制但从未在任何 capture 方法中被实际使用
- **优化建议**: 改用 `async let` 一次性发起所有 10 个捕获并 `await` 全部完成，将总耗时从逐个等待降为最慢子项耗时；对 `screen`、`selection`、`clipboardRisk` 等非关键维度实现懒加载——仅当调用方显式请求时才触发捕获，不在 `refresh()` 中强制拉取；对 `healthStatus()` 之外的维度也接入 TTL 缓存
- **预期提升**: 上下文刷新时间从 T_total = sum(T_i) 降为 T_total = max(T_i)，典型场景从 3-5s 降至 0.3-0.8s

## 2. ActionEngine.swift — 历史记录 O(n) 扫描与无界增长

- **当前复杂度**: `_history` 检索 O(n)，`getRecentHistory(limit:)` 对全量数组调用 `suffix(limit)` 需 O(n) 遍历；`_records` 和 `_history` 均无上限
- **瓶颈**: 所有已完成记录持续追加到 `_history`（line 186），程序运行期间无任何淘汰机制。操作类型(risk level、status)无二级索引，查询特定类型操作需要全量扫描。`ActionRecord` 结构体含 `auditTrail: [AuditEntry]`，每次状态变更都执行一次完整 COW 拷贝
- **优化建议**: 对 `_history` 设置容量上限（如 5000 条），超过时移除最旧条目；对常见查询维度（status、riskLevel、type）建立字典索引；将 `getRecentHistory` 改为基于环形缓冲区的 O(1) 切片操作；高频状态变更可改为 in-place 更新而非 copy-modify-write
- **预期提升**: 历史查询从 O(n) 降为接近 O(1)，长期运行内存占用从无界变为可控

## 3. ModeManager.swift — evaluate() 每次重新排序与冗余 Set 操作

- **当前复杂度**: `evaluate()` O(m log m + m)，m 为激活模式数；`findBlockingMode()` 每次调用都执行 `.sorted()` 创建新数组
- **瓶颈**: `evaluate()` → `findBlockingMode()` 每次操作决策必经路径，排序开销虽然常数小但调用频繁（每次操作检查），无缓存。`toggle()`（line 160-163）执行两次 `Set.contains()` 检查（`isActive()` + `activate()`/`deactivate()` 内部 guard），可合并为单次操作
- **优化建议**: `findBlockingMode()` 移除 `.sorted()`——模式求值逻辑是独立正交的，不需要排序；自定义 handler 注册时直接存储求值顺序，避免每次遍历重新计算顺序；`toggle()` 使用 `Set` 的 `insert()`/`remove()` 返回值直接判断存在性，省去冗余 contains 调用
- **预期提升**: 每次操作决策省去排序开销和冗余 Set 操作，m <= 10 时延迟降低 30-50%

## 4. CommandAllowlist.swift — 命令校验 O(p + b + d) 线性扫描

- **当前复杂度**: `allows()` 对每条命令: O(1) Set 精确匹配 + O(p * L) 前缀匹配 + O(b) 模式扫描 + O(d) 危险管道检测。b = 139 条阻断模式
- **瓶颈**: 对阻断模式采用 `[BlockedCommandPattern]` 线性扫描，每条匹配调用 `hasPrefix` + `localizedStandardContains` 字符串操作。`allowedPrefixes` 也是线性扫描（line 162），对 git、docker、brew 等高频前缀需逐个比较。`containsDangerousPipeline()` 再次线性扫描 14 个后缀。累积到每次 `allows()` 调用约 150+ 次字符串操作
- **优化建议**: 将 `blockedPatterns` 按 `commandPrefix` 分组构建前缀字典（`[String: [BlockedCommandPattern]]`），实现前缀预过滤后再扫描子集；将 `allowedPrefixes` 改为 Trie 树或前缀集合并用 `first(where:)` 优化；将 `containsDangerousPipeline()` 的 14 个后缀合并为单个正则表达式
- **预期提升**: 批量命令校验从 O(150+ 字符串操作) 降为 O(10-20)，ShellExecutor 高频调用路径延迟降低 60-80%

## 5. CredentialSanitizer.swift — 每次调用重复编译 37 个正则表达式

- **当前复杂度**: 每次 `sanitize()` 调用经历 37 次 `try! NSRegularExpression(pattern:)` 运行时编译 + 37 次 `stringByReplacingMatches` 字符串替换
- **瓶颈**: `credentialKeyValuePatterns` 的 25 个模式、`sanitizeInlineCredentials` 的 2 个、`sanitizeAuthorizationHeader` 的 7 个、`sanitizeJWT` 的 1 个、`sanitizeURLCredentials` 的 1 个、`sanitizeBase64` 的 1 个——全部是运行时 `try!` 编译。自定义规则（line 103-108）也在运行时 `try?` 编译。这段路径在日志脱敏和凭据过滤中高频调用
- **优化建议**: 将所有 `NSRegularExpression` 提取为 `nonisolated private static let` 预编译实例，类加载时一次性编译；自定义规则可传入预编译的 `NSRegularExpression` 而非原始 pattern 字符串；对纯文本无凭据的常见输入添加快速短路判断（先检查是否含敏感关键词再启动正则流水线）
- **预期提升**: 每条日志/文本脱敏从 37 次正则编译降为 0 次编译（仅首次），高频调用场景延迟降低 85-95%

## 6. DevContextProvider.swift — 与 ContextProvider 相同的串联瓶颈

- **当前复杂度**: O(10 * T)，最坏预期 100s
- **瓶颈**: 与 ContextProvider 完全相同的模式：`DevContextManager.refresh()` 中 10 个 await 串联执行，各自带 10 秒超时。`repo`/`diff`/`testState`/`buildState` 等 Git 密集型操作通常耗时数百毫秒，串联后累计可达数秒
- **优化建议**: 使用 `async let` 并行化；将 `ciState`、`issue`、`pr` 这类需要网络请求的维度设为可选延迟加载，仅当处于开发者模式且配置了 CI 凭证时才激活；对 `capturedAt` 较新的快照跳过刷新
- **预期提升**: 开发上下文刷新从 2-5s 降至 0.5-1s

## 7. RAGEngine.swift — 文件索引 O(n) 全量读取 + 逐正则编译

- **当前复杂度**: 索引 O(n * F)，其中 n 为文件数，F 为文件大小；搜索 O(k * h * L)，k 为关键词数，h 为命中数，L 为行数
- **瓶颈**: `indexProject()` 通过 `String(contentsOfFile:)` 读取**整个文件**到内存，但后续只取 `.prefix(5000)`——对大文件浪费大量 I/O 和内存。`tokenize()` 每次调用使用 `replacingOccurrences(of:with:options: .regularExpression)` 隐式编译正则表达式。`findRelevantSnippet()` 对每个查询逐行扫描全文（O(L)），无预构建的行级倒排索引。全部文件串行索引，无并行处理
- **优化建议**: 使用 `FileHandle` 或 `InputStream` 仅读取文件前 5000 字节而非全量；将 `tokenize` 的正则替换拆分为 `CharacterSet` 过滤或编译为 `static let` 正则；对 snippet 搜索预建每文件的行级索引（关键词→行号映射）；使用 `withTaskGroup` 将文件索引并行化，每个核心处理一个文件
- **预期提升**: 大项目索引时间从 30s+ 降为 5-10s（利用多核），搜索延迟从 O(L) 降为 O(log L)

## 8. LMCache.swift — LRU 删除 O(n) + DiskTier 同步 JSON 编码

- **当前复杂度**: LRU 操作 O(n)（n 为缓存条目数），`set()` 调用写满三层缓存
- **瓶颈**: `MemoryTier` 中 `lru.removeAll { $0 == key }`（line 113/121/127/133）每次 get/set/touch/remove 都线性扫描 LRU 数组。`cacheKey()` 使用 `.hashValue`（line 92）在进程间不稳定，重启后缓存完全失效。`set()` 方法（line 56-59）写入全部三层，其中 DiskTier 每次做完整 JSON 编码+原子写入，对热数据（tier1）来说完全不需要下写到磁盘。DiskTier 的 `prune()`（line 190-223）每次调用遍历目录内所有文件的 attributes，即使缓存很小
- **优化建议**: 将 LRU 实现改为 `OrderedDictionary` 或 `LinkedList` 结构，删除操作 O(1)；`set()` 只写入 tier1，晋升到 tier2/tier3 仅在访问频率达到阈值时异步下沉；DiskTier `prune()` 按批次惰性清理而非每次同步执行；`cacheKey()` 使用 `SHA256` 或 `MD5` 替代 `hashValue` 保证跨进程稳定性
- **预期提升**: LRU 操作从 O(n) 降为 O(1)，缓存写入减少 60%（仅写入需要的层级），磁盘 I/O 节省 90%（异步下沉）
