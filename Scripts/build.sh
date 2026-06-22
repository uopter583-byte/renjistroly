#!/usr/bin/env bash
# RenJistroly 构建脚本
# 使用: ./Scripts/build.sh [debug|release|clean]
#   debug   — Debug 构建（默认）
#   release — Release 构建
#   clean   — 清理构建产物
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-debug}"

case "$MODE" in
    debug)
        echo "==> Debug 构建..."
        swift build -c debug
        echo "OK: Debug 构建完成"
        echo "   二进制: $(swift build -c debug --show-bin-path 2>/dev/null)/RenJistroly"
        ;;
    release)
        echo "==> Release 构建..."
        swift build -c release
        echo "OK: Release 构建完成"
        echo "   二进制: $(swift build -c release --show-bin-path 2>/dev/null)/RenJistroly"
        ;;
    clean)
        echo "==> 清理构建产物..."
        swift package clean
        rm -rf .build
        echo "OK: 清理完成"
        ;;
    *)
        echo "用法: $0 [debug|release|clean]" >&2
        exit 1
        ;;
esac
