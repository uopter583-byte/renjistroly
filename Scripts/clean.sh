#!/usr/bin/env bash
# RenJistroly 项目清理脚本
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

case "${1:-all}" in
  build)
    echo "🧹 清理构建产物..."
    rm -rf .build
    ;;
  derived)
    echo "🧹 清理 DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/RenJistroly*
    ;;
  packages)
    echo "🧹 清理 Package 缓存..."
    rm -rf ~/Library/Caches/org.swift.swiftpm
    ;;
  all)
    echo "🧹 完整清理..."
    rm -rf .build
    rm -rf ~/Library/Developer/Xcode/DerivedData/RenJistroly*
    rm -rf ~/Library/Caches/org.swift.swiftpm
    echo "✅ 清理完成"
    ;;
  *)
    echo "用法: $0 {build|derived|packages|all}"
    exit 1
    ;;
esac
