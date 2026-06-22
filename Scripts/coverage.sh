#!/bin/bash
# 生成测试覆盖率报告
# Usage: SCRATCH_PATH=/tmp/mypath ./Scripts/coverage.sh
set -euo pipefail

BUILD_DIR="${SCRATCH_PATH:-.build}"

# 构建并测试（带覆盖率）
swift test --enable-code-coverage ${SCRATCH_PATH:+--scratch-path "$SCRATCH_PATH"}

# 查找 .profdata 文件
PROFDATA=$(find "$BUILD_DIR" -name "*.profdata" | head -1)
BINARY=$(find "$BUILD_DIR" -name "RenJistroly*" -type f -perm -u+x | head -1)

if [ -n "$PROFDATA" ] && [ -n "$BINARY" ]; then
    echo "→ 生成覆盖率报告..."
    # 生成报告
    xcrun llvm-cov report "$BINARY" --instr-profile="$PROFDATA" \
        --ignore-filename-regex="Tests|.build" \
        --use-color > docs/coverage-report.txt

    # 生成 HTML
    mkdir -p docs/coverage-html
    xcrun llvm-cov show "$BINARY" --instr-profile="$PROFDATA" \
        --ignore-filename-regex="Tests|.build" \
        --format=html > docs/coverage-html/index.html

    echo "✅ 覆盖率报告已生成: docs/coverage-report.txt"
    echo "       HTML 报告:    docs/coverage-html/index.html"
else
    echo "⚠️ 未找到覆盖率数据文件"
    echo "   PROFDATA: ${PROFDATA:-未找到}"
    echo "   BINARY:  ${BINARY:-未找到}"
fi
