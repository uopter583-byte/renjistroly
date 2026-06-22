#!/usr/bin/env bash
# RenJistroly 开发环境配置脚本
# 使用: ./Scripts/setup.sh
set -euo pipefail

echo "==> 配置 RenJistroly 开发环境..."

# 检查 Swift
if ! command -v swift &> /dev/null; then
    echo "错误: 需要安装 Swift (Xcode)" >&2
    exit 1
fi
echo "OK: Swift 已安装 ($(swift --version | head -1))"

# 检查 Xcode 命令行工具
if ! xcode-select -p &> /dev/null; then
    echo "错误: 需要安装 Xcode 命令行工具" >&2
    echo "  运行: xcode-select --install" >&2
    exit 1
fi
echo "OK: Xcode 命令行工具已安装"

# 生成 Package.resolved
echo "==> 解析依赖..."
swift package resolve

# 构建
echo "==> 构建项目..."
swift build

# 运行测试
echo "==> 运行测试..."
swift test

echo "==> 环境配置完成"
echo ""
echo "可用命令:"
echo "  ./Scripts/build.sh [debug|release|clean]  — 构建"
echo "  ./Scripts/test.sh [unit|integration|security|performance|all]  — 测试"
echo "  ./Scripts/lint.sh  — 代码检查"
echo "  ./Scripts/compile_and_run.sh [--test]  — 打包并启动应用"
