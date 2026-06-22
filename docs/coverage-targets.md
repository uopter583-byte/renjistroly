# 代码覆盖率目标

| 模块 | 当前目标 | 长期目标 |
|------|---------|---------|
| RenJistrolyEnterprise | 80% | 90% |
| RenJistrolyProductIdentity | 75% | 85% |
| RenJistrolySystemBridge | 70% | 80% |
| RenJistrolyCapability | 60% | 75% |
| RenJistrolyModels | 85% | 95% |
| RenJistrolyIntelligence | 65% | 80% |
| RenJistrolyConversation | 60% | 75% |
| RenJistrolyUI | 50% | 65% |

## 覆盖策略

- **单元测试**: 覆盖核心业务逻辑、边界条件、错误路径
- **集成测试**: 验证模块间交互和数据流
- **安全测试**: 覆盖权限检查、输入验证、注入防护

## 运行方式

```bash
./Scripts/coverage.sh
```

报告将输出到 `docs/coverage-report.txt` 和 `docs/coverage-html/index.html`。
