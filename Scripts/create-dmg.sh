#!/usr/bin/env bash
# 创建 RenJistroly DMG 安装包
# 用法: ./Scripts/create-dmg.sh [--no-sign] [--skip-layout] [--background <path>]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ── 配置 ──────────────────────────────────────────────────────────────────
if [[ -f "$ROOT/version.env" ]]; then
  source "$ROOT/version.env"
fi

APP_NAME="${APP_NAME:-RenJistroly}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_BUNDLE="$ROOT/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${MARKETING_VERSION}"
DMG_PATH="$ROOT/${DMG_NAME}.dmg"
STAGING_DIR="$ROOT/.build/dmg_staging"

# DMG 窗口布局（pt）
WINDOW_X=200
WINDOW_Y=200
WINDOW_W=600
WINDOW_H=420
ICON_SIZE=96
APP_X=150
APP_Y=180
APPLICATIONS_X=400
APPLICATIONS_Y=180

# ── 参数解析 ──────────────────────────────────────────────────────────────
DO_SIGN=true
SKIP_LAYOUT=false
BACKGROUND_IMAGE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-sign) DO_SIGN=false; shift ;;
    --skip-layout) SKIP_LAYOUT=true; shift ;;
    --background) BACKGROUND_IMAGE="$2"; shift 2 ;;
    --help|-h)
      echo "用法: $0 [--no-sign] [--skip-layout] [--background <路径>]"
      exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ── 前置检查 ──────────────────────────────────────────────────────────────
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "错误: 未找到 ${APP_BUNDLE}，请先运行 Scripts/package_app.sh" >&2
  exit 1
fi

# ── 清理 ──────────────────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
trap 'rm -rf "$STAGING_DIR"' EXIT

# ── 准备 DMG 内容 ─────────────────────────────────────────────────────────
echo "==> 准备 DMG 内容..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 可选背景图
if [[ -n "$BACKGROUND_IMAGE" && -f "$BACKGROUND_IMAGE" ]]; then
  mkdir -p "$STAGING_DIR/.background"
  cp "$BACKGROUND_IMAGE" "$STAGING_DIR/.background/"
  BACKGROUND_FILE="$(basename "$BACKGROUND_IMAGE")"
fi

# ── 创建 DMG ──────────────────────────────────────────────────────────────
echo "==> 创建 DMG..."
if [[ -f "$DMG_PATH" ]]; then
  rm "$DMG_PATH"
fi

hdiutil create \
  -volname "${DMG_NAME}" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

# ── 布局和美化（挂载后设置 Finder 窗口） ──────────────────────────────────
if ! $SKIP_LAYOUT; then
  echo "==> 配置 DMG 窗口布局..."
  TEMP_MOUNT="/Volumes/${DMG_NAME}"
  ATTACH_OUTPUT="$(hdiutil attach "$DMG_PATH" -noverify -noautoopen)"
  DEV_NAME="$(awk -v mount="$TEMP_MOUNT" '$0 ~ mount { print $1; exit }' <<<"$ATTACH_OUTPUT")"

  # 设置窗口位置和大小
  BACKGROUND_SCRIPT=""
  if [[ -n "${BACKGROUND_FILE:-}" ]]; then
    BACKGROUND_SCRIPT="set background picture of the icon view options of container window to file \".background:${BACKGROUND_FILE}\""
  fi

  osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${DMG_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {${WINDOW_X}, ${WINDOW_Y}, $((WINDOW_X + WINDOW_W)), $((WINDOW_Y + WINDOW_H))}
    set icon size of the icon view options of container window to ${ICON_SIZE}
    set arrangement of the icon view options of container window to not arranged
    ${BACKGROUND_SCRIPT}
    delay 1
    set position of item "${APP_NAME}.app" of container window to {${APP_X}, ${APP_Y}}
    set position of item "Applications" of container window to {${APPLICATIONS_X}, ${APPLICATIONS_Y}}
    close
  end tell
end tell
APPLESCRIPT

  # 等待 Finder 更新
  sleep 2

  # 重新挂载为只读（固化布局）
  if [[ -n "$DEV_NAME" ]]; then
    hdiutil detach "$DEV_NAME" -quiet 2>/dev/null || true
  fi
else
  echo "==> 跳过 Finder 窗口布局"
fi

# 去弹窗（设置自动弹出不检查）
set -x
TMP_DMG_PATH="${DMG_PATH}.tmp.dmg"
rm -f "$TMP_DMG_PATH"
hdiutil convert "$DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "$TMP_DMG_PATH"
mv "$TMP_DMG_PATH" "$DMG_PATH"
set +x

# ── 签名 DMG ──────────────────────────────────────────────────────────────
if $DO_SIGN && [[ -n "${APP_IDENTITY:-}" ]]; then
  echo "==> 签名 DMG..."
  codesign --force --timestamp --sign "$APP_IDENTITY" "$DMG_PATH"
elif $DO_SIGN && [[ -z "${APP_IDENTITY:-}" ]]; then
  echo "  -> 未设置 APP_IDENTITY，跳过 DMG 签名"
fi

# ── 完成 ──────────────────────────────────────────────────────────────────
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "========================================"
echo "  DMG 创建完成"
echo "  文件: ${DMG_PATH}"
echo "  大小: ${DMG_SIZE}"
echo "  签名: ${DO_SIGN} (身份: ${APP_IDENTITY:-(无)})"
echo "========================================"
echo ""
echo "  如果需要公证，运行:"
echo "    ./Scripts/notarize.sh"
echo "========================================"
