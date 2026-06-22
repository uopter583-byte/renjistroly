#!/usr/bin/env bash
# RenJistroly 版本号升级工具
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 读取当前版本
source "$ROOT/version.env"

# 从 MARKETING_VERSION 解析主版本号
IFS='.' read -r MAJOR MINOR PATCH <<< "${MARKETING_VERSION:-0.0.0}"

case "${1:-patch}" in
  major)
    NEW_MAJOR=$((MAJOR + 1))
    NEW_MINOR=0
    NEW_PATCH=0
    ;;
  minor)
    NEW_MAJOR=$MAJOR
    NEW_MINOR=$((MINOR + 1))
    NEW_PATCH=0
    ;;
  patch)
    NEW_MAJOR=$MAJOR
    NEW_MINOR=$MINOR
    NEW_PATCH=$((PATCH + 1))
    ;;
  *)
    echo "用法: $0 {major|minor|patch}"
    exit 1
    ;;
esac

BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="$NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"

# 写入 version.env（向后兼容：保留 BUNDLE_ID / APP_VERSION）
cat > "$ROOT/version.env" << EOF
APP_NAME=RenJistroly
BUNDLE_ID=$BUNDLE_ID
MAJOR=$NEW_MAJOR
MINOR=$NEW_MINOR
PATCH=$NEW_PATCH
BUILD_NUMBER=$BUILD_NUMBER
APP_VERSION=$NEW_VERSION
MARKETING_VERSION=$NEW_VERSION
EOF

# 更新 Resources/Info.plist
if [ -f "$ROOT/Resources/Info.plist" ]; then
    plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" "$ROOT/Resources/Info.plist"
    plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$ROOT/Resources/Info.plist"
fi

# 更新打包后的 app 内 Info.plist（如果存在）
BUILT_PLIST="$ROOT/build/RenJistroly.app/Contents/Info.plist"
if [ -f "$BUILT_PLIST" ]; then
    plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" "$BUILT_PLIST"
    plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$BUILT_PLIST"
fi

echo " 版本升级: $MARKETING_VERSION -> $NEW_VERSION (build $BUILD_NUMBER)"
