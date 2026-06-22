#!/usr/bin/env bash
# RenJistroly 配置同步与完整性检查脚本
# 用法: ./Scripts/sync-config.sh [--backup|--check|--restore]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR="$ROOT/.config-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

backup_config() {
  echo "==> 备份当前配置..."
  mkdir -p "$BACKUP_DIR/$TIMESTAMP"

  for f in version.env HelperConfig/com.renjistroly.helper.plist \
           HelperConfig/Info.plist Resources/Info.plist Resources/entitlements.plist; do
    if [[ -f "$f" ]]; then
      cp "$f" "$BACKUP_DIR/$TIMESTAMP/"
      echo "  ✅ 已备份: $f"
    else
      echo "  ⚠️  跳过 (不存在): $f"
    fi
  done

  echo "备份位置: $BACKUP_DIR/$TIMESTAMP"
}

restore_config() {
  SNAPSHOTS=("$BACKUP_DIR"/*/)
  if [[ ${#SNAPSHOTS[@]} -eq 0 ]]; then
    echo "错误: 没有可用的备份" >&2
    exit 1
  fi

  echo "可用的备份:"
  for i in "${!SNAPSHOTS[@]}"; do
    SNAP_NAME=$(basename "${SNAPSHOTS[$i]}")
    echo "  [$((i+1))] $SNAP_NAME"
  done

  read -r -p "选择要恢复的备份编号 [1-${#SNAPSHOTS[@]}]: " choice
  if [[ "$choice" -lt 1 || "$choice" -gt "${#SNAPSHOTS[@]}" ]]; then
    echo "错误: 无效选择" >&2
    exit 1
  fi

  SRC="${SNAPSHOTS[$((choice-1))]}"
  echo "==> 从 $(basename "$SRC") 恢复..."

  for f in "$SRC"/*; do
    FNAME=$(basename "$f")
    # 映射回项目相对路径
    case "$FNAME" in
      version.env)            DEST="version.env" ;;
      com.renjistroly.helper.plist) DEST="HelperConfig/$FNAME" ;;
      Info.plist)
        if [[ -f "HelperConfig/$FNAME" ]] && [[ ! -f "Resources/$FNAME" ]]; then
          DEST="HelperConfig/$FNAME"
        else
          DEST="Resources/$FNAME"
        fi
        ;;
      entitlements.plist)     DEST="Resources/$FNAME" ;;
      *)                      echo "  ⚠️  未知文件: $FNAME, 跳过"; continue ;;
    esac

    if [[ -f "$DEST" ]]; then
      cp "$DEST" "${DEST}.bak"
      echo "  💾 当前文件已备份为: ${DEST}.bak"
    fi
    cp "$f" "$DEST"
    echo "  ✅ 已恢复: $DEST"
  done

  echo "恢复完成"
}

check_integrity() {
  echo "==> 检查配置完整性..."
  ISSUES=0

  # version.env
  if [[ -f version.env ]]; then
    source version.env
    REQUIRED_FIELDS=(APP_NAME BUNDLE_ID APP_VERSION MARKETING_VERSION BUILD_NUMBER)
    for field in "${REQUIRED_FIELDS[@]}"; do
      if [[ -z "${!field:-}" ]]; then
        echo "  ❌ version.env: 缺少 $field"
        ((ISSUES++))
      fi
    done
    if [[ "$ISSUES" -eq 0 ]]; then
      echo "  ✅ version.env 完整"
    fi
  else
    echo "  ❌ version.env 缺失"
    ((ISSUES++))
  fi

  # Info.plist (Resource)
  if [[ -f Resources/Info.plist ]]; then
    if plutil -lint Resources/Info.plist &>/dev/null; then
      echo "  ✅ Resources/Info.plist 格式正确"
    else
      echo "  ❌ Resources/Info.plist 格式错误"
      ((ISSUES++))
    fi
  else
    echo "  ⚠️  Resources/Info.plist 不存在"
  fi

  # entitlements.plist
  if [[ -f Resources/entitlements.plist ]]; then
    if plutil -lint Resources/entitlements.plist &>/dev/null; then
      echo "  ✅ Resources/entitlements.plist 格式正确"
    else
      echo "  ❌ Resources/entitlements.plist 格式错误"
      ((ISSUES++))
    fi
  else
    echo "  ⚠️  Resources/entitlements.plist 不存在"
  fi

  # Helper Config
  for f in HelperConfig/com.renjistroly.helper.plist HelperConfig/Info.plist; do
    if [[ -f "$f" ]]; then
      if plutil -lint "$f" &>/dev/null; then
        echo "  ✅ $f 格式正确"
      else
        echo "  ❌ $f 格式错误"
        ((ISSUES++))
      fi
    else
      echo "  ⚠️  $f 不存在"
    fi
  done

  # 同步 vendor 示例文件（非破坏性）
  if [[ -f _vendored/aisuite/.env.sample ]]; then
    if [[ ! -f _vendored/aisuite/.env ]]; then
      cp _vendored/aisuite/.env.sample _vendored/aisuite/.env
      echo "  📋 已从模板创建 _vendored/aisuite/.env"
    fi
  fi

  if [[ -f _vendored/chatwoot/.env.example ]]; then
    if [[ ! -f _vendored/chatwoot/.env ]]; then
      cp _vendored/chatwoot/.env.example _vendored/chatwoot/.env
      echo "  📋 已从模板创建 _vendored/chatwoot/.env"
    fi
  fi

  echo ""
  if [[ "$ISSUES" -eq 0 ]]; then
    echo "✅ 所有配置完整"
  else
    echo "❌ 发现 ${ISSUES} 个问题，请修复"
    return 1
  fi
}

# --- Main ---
case "${1:-check}" in
  backup)
    backup_config
    ;;
  restore)
    restore_config
    ;;
  check)
    check_integrity
    ;;
  *)
    echo "用法: $0 {backup|restore|check}"
    echo ""
    echo "  backup  — 备份当前配置文件到 .config-backups/"
    echo "  restore — 从备份恢复配置"
    echo "  check   — 检查配置完整性 (默认)"
    exit 1
    ;;
esac
