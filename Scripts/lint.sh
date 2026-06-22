#!/usr/bin/env bash
# RenJistroly 代码格式检查脚本
# 使用: ./Scripts/lint.sh [check|format]
#   check   — 仅检查格式差异（默认）
#   format  — 自动格式化代码
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-check}"

# 优先使用 swiftformat（项目自带 .swiftformat 配置）
if command -v swiftformat &> /dev/null; then
    case "$MODE" in
        check)
            echo "==> 检查代码格式 (swiftformat --lint)..."
            if swiftformat --lint Sources/ Tests/ --quiet 2>/dev/null; then
                echo "OK: 代码格式合规"
            else
                echo "建议: 运行 ./Scripts/lint.sh format 自动格式化" >&2
                exit 1
            fi
            ;;
        format)
            echo "==> 自动格式化代码 (swiftformat)..."
            swiftformat Sources/ Tests/
            echo "OK: 格式化完成"
            ;;
        *)
            echo "用法: $0 [check|format]" >&2
            exit 1
            ;;
    esac
else
    echo "警告: swiftformat 未安装，跳过代码格式检查" >&2
    echo "  安装: brew install swiftformat" >&2
    echo "  或: mint install nicklockwood/SwiftFormat" >&2
    exit 1
fi
