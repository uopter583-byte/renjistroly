#!/usr/bin/env bash
# RenJistroly 测试脚本
# 使用: ./Scripts/test.sh [unit|integration|security|performance|regression|all]
#   unit        — 模块单元测试
#   integration — 集成测试 + UI 测试 + 人机交互测试
#   security    — 安全测试
#   performance — 性能测试
#   regression  — 回归测试
#   all         — 全部测试
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CATEGORY="${1:-unit}"

case "$CATEGORY" in
    unit)
        echo "==> 运行模块单元测试..."
        swift test --filter "RenJistrolyModelsTests"
        swift test --filter "RenJistrolySystemBridgeTests"
        swift test --filter "RenJistrolyIntelligenceTests"
        swift test --filter "RenJistrolyCapabilityTests"
        swift test --filter "RenJistrolyConversationTests"
        swift test --filter "RenJistrolyTests"
        echo "OK: 单元测试完成"
        ;;
    integration)
        echo "==> 运行集成测试..."
        swift test --filter "IntegrationTests"
        swift test --filter "HumanInteractionTests"
        swift test --filter "UITests"
        echo "OK: 集成测试完成"
        ;;
    security)
        echo "==> 运行安全测试..."
        swift test --filter "SecurityTests"
        echo "OK: 安全测试完成"
        ;;
    performance)
        echo "==> 运行性能测试..."
        swift test --filter "PerformanceTests"
        echo "OK: 性能测试完成"
        ;;
    regression)
        echo "==> 运行回归测试..."
        swift test --filter "RegressionTests"
        echo "OK: 回归测试完成"
        ;;
    all)
        echo "==> 运行全部测试（含 LongRunning）..."
        swift test
        echo "OK: 全部测试完成"
        ;;
    *)
        echo "用法: $0 [unit|integration|security|performance|regression|all]" >&2
        exit 1
        ;;
esac
