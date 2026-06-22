#!/usr/bin/env bash
# RenJistroly 应用打包
# 构建多架构（arm64/x86_64）universal binary 并生成 .app 包
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ── 配置 ──────────────────────────────────────────────────────────────────
if [[ -f "$ROOT/version.env" ]]; then
  source "$ROOT/version.env"
fi

APP_NAME="${APP_NAME:-RenJistroly}"
BUNDLE_ID="${BUNDLE_ID:-com.renjistroly.app}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER=${BUILD_NUMBER:-1}
MACOS_MIN_VERSION="${MACOS_MIN_VERSION:-15.0}"
MENU_BAR_APP=${MENU_BAR_APP:-0}
SIGNING_MODE=${SIGNING_MODE:-}
APP_IDENTITY="${APP_IDENTITY:-}"
CONF="${CONF:-release}"

# 架构列表
ARCH_LIST=(${ARCHES:-})
if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  ARCH_LIST=("$(uname -m)")
fi

# ── Helper: 设置 SMAuthorizedClients ─────────────────────────────────────
# 避免每次修改源码，只影响 bundles — 暂时跳过。

# ── 构建 ──────────────────────────────────────────────────────────────────
echo "==> 构建 ${APP_NAME} (架构: ${ARCH_LIST[*]}, 模式: ${CONF})"
for arch in "${ARCH_LIST[@]}"; do
  swift build -c "$CONF" --arch "$arch"
  swift build -c "$CONF" --arch "$arch" --product "${APP_NAME}Helper" 2>/dev/null || true
done

# ── 创建 .app 包 ─────────────────────────────────────────────────────────
APP_BUNDLE="$ROOT/${APP_NAME}.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
mkdir -p "$APP_BUNDLE/Contents/Library/LaunchServices"

# ── Info.plist ────────────────────────────────────────────────────────────
LSUI_VALUE="false"
[[ "$MENU_BAR_APP" == "1" ]] && LSUI_VALUE="true"

BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

if [[ -f "$ROOT/Resources/Info.plist" ]]; then
  cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace BuildTimestamp -string "$BUILD_TIMESTAMP" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
  plutil -replace GitCommit -string "$GIT_COMMIT" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
  plutil -replace LSUIElement -bool "$([[ $MENU_BAR_APP == 1 ]] && echo true || echo false)" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
else
  cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><${LSUI_VALUE}/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>RenJistroly 使用语音识别将你的语音转为文字指令，所有处理在设备端完成。</string>
    <key>NSMicrophoneUsageDescription</key><string>RenJistroly 需要麦克风权限以接收你的语音输入。</string>
    <key>NSAccessibilityUsageDescription</key><string>RenJistroly 需要辅助功能权限来读取界面状态、输入文字并按你的指令控制 Mac。</string>
    <key>NSScreenCaptureUsageDescription</key><string>RenJistroly 需要屏幕录制权限来理解当前屏幕内容并提供上下文辅助。</string>
    <key>NSAppleEventsUsageDescription</key><string>RenJistroly 使用 Apple Events 来控制应用和自动化操作。</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST
fi

# ── Helper 函数 ───────────────────────────────────────────────────────────
build_product_path() {
  local name="$1" arch="$2"
  case "$arch" in
    arm64|x86_64) echo ".build/${arch}-apple-macosx/$CONF/$name" ;;
    *) echo ".build/$CONF/$name" ;;
  esac
}

verify_binary_arches() {
  local binary="$1"; shift
  local expected=("$@")
  local actual
  actual=$(lipo -archs "$binary")
  local actual_count expected_count
  actual_count=$(wc -w <<<"$actual" | tr -d ' ')
  expected_count=${#expected[@]}
  if [[ "$actual_count" -ne "$expected_count" ]]; then
    echo "ERROR: ${binary} 架构不匹配 (期望: ${expected[*]}, 实际: ${actual})" >&2
    exit 1
  fi
  for arch in "${expected[@]}"; do
    if [[ "$actual" != *"$arch"* ]]; then
      echo "ERROR: ${binary} 缺少架构 ${arch} (当前: ${actual})" >&2
      exit 1
    fi
  done
}

install_binary() {
  local name="$1" dest="$2"
  local binaries=()
  for arch in "${ARCH_LIST[@]}"; do
    local src
    src=$(build_product_path "$name" "$arch")
    if [[ ! -f "$src" ]]; then
      echo "ERROR: 缺少 ${name} 的 ${arch} 构建产物: ${src}" >&2
      exit 1
    fi
    binaries+=("$src")
  done
  if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$dest"
  else
    cp "${binaries[0]}" "$dest"
  fi
  chmod +x "$dest"
  verify_binary_arches "$dest" "${ARCH_LIST[@]}"
}

# ── 安装主程序 ────────────────────────────────────────────────────────────
install_binary "$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# ── 安装 Privileged Helper ───────────────────────────────────────────────
HELPER_NAME="${APP_NAME}Helper"
if [[ -f "$(build_product_path "$HELPER_NAME" "${ARCH_LIST[0]}")" ]]; then
  HELPER_BUNDLE_ID="com.renjistroly.helper"
  HELPER_DEST="$APP_BUNDLE/Contents/Library/LaunchServices/$HELPER_BUNDLE_ID"
  install_binary "$HELPER_NAME" "$HELPER_DEST"
  echo "  -> 已安装 Helper: $HELPER_BUNDLE_ID"
fi

# ── 复制资源 ──────────────────────────────────────────────────────────────
# 源码资源文件夹
APP_RESOURCES_DIR="$ROOT/Sources/$APP_NAME/Resources"
if [[ -d "$APP_RESOURCES_DIR" ]]; then
  cp -R "$APP_RESOURCES_DIR/." "$APP_BUNDLE/Contents/Resources/"
fi

# SwiftPM 资源 bundle（构建产物旁的 .bundle 目录）
PREFERRED_BUILD_DIR="$(dirname "$(build_product_path "$APP_NAME" "${ARCH_LIST[0]}")")"
shopt -s nullglob
for bundle in "${PREFERRED_BUILD_DIR}/"*.bundle; do
  cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
done
shopt -u nullglob

# ── 嵌入 Framework ────────────────────────────────────────────────────────
FRAMEWORK_SOURCE_DIRS=(".build/$CONF" ".build/${ARCH_LIST[0]}-apple-macosx/$CONF")
for dir in "${FRAMEWORK_SOURCE_DIRS[@]}"; do
  if compgen -G "${dir}/*.framework" >/dev/null 2>&1; then
    cp -R "${dir}/"*.framework "$APP_BUNDLE/Contents/Frameworks/"
    chmod -R a+rX "$APP_BUNDLE/Contents/Frameworks"
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
      "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    break
  fi
done

# ── 嵌入 onnxruntime ─────────────────────────────────────────────────────
ORT_DYLIB="$ROOT/Frameworks/libonnxruntime.1.26.0.dylib"
if [[ -f "$ORT_DYLIB" ]]; then
  cp "$ORT_DYLIB" "$APP_BUNDLE/Contents/Frameworks/"
  ln -sf "libonnxruntime.1.26.0.dylib" "$APP_BUNDLE/Contents/Frameworks/libonnxruntime.1.dylib"
  if [[ -f "$ROOT/Frameworks/libonnxruntime.dylib" ]]; then
    cp "$ROOT/Frameworks/libonnxruntime.dylib" "$APP_BUNDLE/Contents/Frameworks/"
  fi
  install_name_tool -change \
    "/opt/homebrew/opt/onnxruntime/lib/libonnxruntime.1.dylib" \
    "@rpath/libonnxruntime.1.dylib" \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
  install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
  echo "  -> 已嵌入 onnxruntime dylibs"
fi

# ── 图标 ──────────────────────────────────────────────────────────────────
ICON_SOURCE="$ROOT/Icon.icon"
ICON_TARGET="$ROOT/Icon.icns"
if [[ -f "$ICON_SOURCE" ]]; then
  iconutil --convert icns --output "$ICON_TARGET" "$ICON_SOURCE"
  echo "  -> 已转换图标"
fi
if [[ -f "$ICON_TARGET" ]]; then
  cp "$ICON_TARGET" "$APP_BUNDLE/Contents/Resources/Icon.icns"
fi

# ── 清理与准备签名 ───────────────────────────────────────────────────────
chmod -R u+w "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"
find "$APP_BUNDLE" -name '._*' -delete

# ── Entitlements ──────────────────────────────────────────────────────────
ENTITLEMENTS_DIR="$ROOT/.build/entitlements"
DEFAULT_ENTITLEMENTS="$ENTITLEMENTS_DIR/${APP_NAME}.entitlements"
mkdir -p "$ENTITLEMENTS_DIR"

APP_ENTITLEMENTS="${APP_ENTITLEMENTS:-$DEFAULT_ENTITLEMENTS}"
if [[ -f "$ROOT/Resources/entitlements.plist" ]]; then
  cp "$ROOT/Resources/entitlements.plist" "$APP_ENTITLEMENTS"
elif [[ ! -f "$APP_ENTITLEMENTS" ]]; then
  cat > "$APP_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
PLIST
fi

# ── 签名 ──────────────────────────────────────────────────────────────────
if [[ "$SIGNING_MODE" == "adhoc" || -z "${APP_IDENTITY:-}" ]]; then
  CODESIGN_ARGS=(--force --sign "-")
else
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
fi

# 先签名 Helper
HELPER_PATH="$APP_BUNDLE/Contents/Library/LaunchServices/com.renjistroly.helper"
if [[ -f "$HELPER_PATH" ]]; then
  codesign "${CODESIGN_ARGS[@]}" --identifier "com.renjistroly.helper" "$HELPER_PATH"
fi

# 签名 Frameworks
for fw in "$APP_BUNDLE/Contents/Frameworks/"*.framework; do
  [[ -d "$fw" ]] || continue
  while IFS= read -r -d '' bin; do
    codesign "${CODESIGN_ARGS[@]}" "$bin"
  done < <(find "$fw" -type f -perm -111 -print0)
  codesign "${CODESIGN_ARGS[@]}" "$fw"
done

# 签名主应用
codesign "${CODESIGN_ARGS[@]}" --identifier "$BUNDLE_ID" --entitlements "$APP_ENTITLEMENTS" "$APP_BUNDLE"

# ── 完成 ──────────────────────────────────────────────────────────────────
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo "========================================"
echo "  $APP_NAME $MARKETING_VERSION (build $BUILD_NUMBER)"
echo "  路径: $APP_BUNDLE"
echo "  大小: $APP_SIZE"
echo "  架构: ${ARCH_LIST[*]}"
echo "  签名: ${APP_IDENTITY:-(ad-hoc)}"
echo "========================================"
