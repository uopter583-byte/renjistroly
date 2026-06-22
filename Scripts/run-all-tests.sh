#!/bin/bash
# 全量测试运行脚本
# 分阶段运行：单元 → 集成 → 安全 → 性能
set -euo pipefail

REPORT="docs/test-report.txt"
mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"

log() {
    local msg="$*"
    echo "$msg"
    echo "$msg" >> "$REPORT"
}

run_phase() {
    local phase_name="$1"
    shift
    log "=== [$(date '+%H:%M:%S')] 阶段: $phase_name ==="

    local start=$(date +%s)
    if "$@"; then
        local end=$(date +%s)
        local elapsed=$((end - start))
        log "✅ $phase_name 通过 ($((elapsed / 60))分$((elapsed % 60))秒)"
    else
        local end=$(date +%s)
        local elapsed=$((end - start))
        log "❌ $phase_name 失败 ($((elapsed / 60))分$((elapsed % 60))秒)"
        return 1
    fi
}

TOTAL_START=$(date +%s)

# Phase 1: 单元测试 — 核心模块
run_phase "单元测试 (Models)" swift test --filter "RenJistrolyModelsTests"
run_phase "单元测试 (综合)" swift test --filter "RenJistrolyTests"

# Phase 2: 集成测试 — 模块间交互
run_phase "集成测试 (SystemBridge)" swift test --filter "RenJistrolySystemBridgeTests"
run_phase "集成测试 (Capability)" swift test --filter "RenJistrolyCapabilityTests"
run_phase "集成测试 (Intelligence)" swift test --filter "RenJistrolyIntelligenceTests"
run_phase "集成测试 (Conversation)" swift test --filter "RenJistrolyConversationTests"

# Phase 3: 安全测试
run_phase "安全测试" swift test --filter "SecurityTests"

# Phase 4: 性能测试
run_phase "性能测试" swift test --filter "PerformanceTests"

TOTAL_END=$(date +%s)
TOTAL_ELAPSED=$((TOTAL_END - TOTAL_START))

log ""
log "========================================="
log "全量测试完成"
log "总耗时: $((TOTAL_ELAPSED / 60))分$((TOTAL_ELAPSED % 60))秒"
log "报告: $REPORT"
log "========================================="
