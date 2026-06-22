#!/usr/bin/env bash
# RenJistroly 项目健康检查脚本
# 用法: ./Scripts/check-health.sh [--verbose]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
WARN=0
VERBOSE=false

[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }
info() { if [[ "$VERBOSE" == true ]]; then echo "     $1"; fi; return 0; }

echo "=============================="
echo " RenJistroly 项目健康检查"
echo "=============================="
echo ""

# --- 1. 工具链检查 ---
echo "【工具链】"

if command -v swift &> /dev/null; then
  SWIFT_VER=$(swift --version | head -1)
  pass "Swift 已安装: $SWIFT_VER"
else
  fail "Swift 未安装 (需要 Xcode)"
fi

if xcode-select -p &> /dev/null; then
  XCODE_PATH=$(xcode-select -p)
  pass "Xcode 命令行工具: $XCODE_PATH"
else
  fail "Xcode 命令行工具未安装"
fi

if command -v xcrun &> /dev/null; then
  pass "xcrun 可用"
else
  fail "xcrun 不可用"
fi

# --- 2. 项目结构检查 ---
echo ""
echo "【项目结构】"

if [[ -f Package.swift ]]; then
  SWIFT_TOOLS_VER=$(head -1 Package.swift | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")
  pass "Package.swift 存在 (swift-tools-version: $SWIFT_TOOLS_VER)"
else
  fail "Package.swift 缺失"
fi

SOURCE_COUNT=$(find Sources -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [[ "$SOURCE_COUNT" -gt 0 ]]; then
  pass "Sources/ 目录非空 (${SOURCE_COUNT} 个模块)"
else
  fail "Sources/ 目录为空"
fi

for mod in \
  RenJistrolyApp RenJistrolyModels RenJistrolySystemBridge \
  RenJistrolyIntelligence RenJistrolyCapability RenJistrolyConversation \
  RenJistrolyUI RenJistrolyMCP; do
  if [[ -d "Sources/$mod" ]]; then
    pass "模块 $mod 存在"
  else
    fail "模块 $mod 缺失"
  fi
done

if [[ -d Tests ]]; then
  TEST_COUNT=$(find Tests -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  pass "Tests/ 目录存在 (${TEST_COUNT} 个测试套件)"
else
  warn "Tests/ 目录不存在"
fi

if [[ -d Resources ]]; then
  RES_COUNT=$(find Resources -type f | wc -l | tr -d ' ')
  pass "Resources/ 存在 (${RES_COUNT} 个资源文件)"
else
  warn "Resources/ 目录缺失"
fi

# --- 3. 构建状态检查 ---
echo ""
echo "【构建状态】"

if [[ -d .build ]]; then
  if [[ -f .build/debug.yaml ]]; then
    BUILD_TIME=$(stat -f "%Sm" .build/debug.yaml 2>/dev/null || echo "unknown")
    pass ".build 存在 (上次构建: $BUILD_TIME)"
  else
    warn ".build 存在但缺少 debug.yaml (可能构建中断)"
  fi

  # 检查是否有任何可执行产物
  BUILT_BINS=$(find .build -type f -perm +111 -name "RenJistroly*" 2>/dev/null | head -5)
  if [[ -n "$BUILT_BINS" ]]; then
    info "已构建的可执行文件:"
    while IFS= read -r bin; do
      info "  - ${bin#./}"
    done <<< "$BUILT_BINS"
  else
    warn "未找到构建产物 (运行 swift build 构建)"
  fi
else
  warn ".build 不存在 (未构建)"
fi

# --- 4. 配置完整性检查 ---
echo ""
echo "【配置完整性】"

if [[ -f version.env ]]; then
  source version.env
  if [[ -n "${APP_VERSION:-}" ]] && [[ -n "${BUNDLE_ID:-}" ]]; then
    pass "version.env 完整 (${APP_NAME:-RenJistroly} v${APP_VERSION:-?})"
  else
    fail "version.env 缺少必要字段"
  fi
else
  fail "version.env 缺失"
fi

if [[ -f Resources/Info.plist ]]; then
  pass "Info.plist 存在"
else
  fail "Resources/Info.plist 缺失"
fi

if [[ -f Resources/entitlements.plist ]]; then
  pass "entitlements.plist 存在"
else
  fail "Resources/entitlements.plist 缺失"
fi

if [[ -d HelperConfig ]]; then
  if [[ -f HelperConfig/com.renjistroly.helper.plist ]]; then
    pass "Helper launchd plist 存在"
  else
    warn "Helper launchd plist 缺失"
  fi
  if [[ -f HelperConfig/Info.plist ]]; then
    pass "Helper Info.plist 存在"
  else
    warn "Helper Info.plist 缺失"
  fi
else
  warn "HelperConfig/ 目录缺失"
fi

# --- 5. 磁盘空间检查 ---
echo ""
echo "【磁盘空间】"

ROOT_DEVICE=$(df "$ROOT" | tail -1)
AVAIL_SPACE=$(echo "$ROOT_DEVICE" | awk '{print $4}')
AVAIL_MB=$((AVAIL_SPACE / 1024))
BUILD_SIZE=$(du -sm .build 2>/dev/null | cut -f1 || echo "0")
DERIVED_SIZE=$(du -sm ~/Library/Developer/Xcode/DerivedData/RenJistroly* 2>/dev/null | awk '{s+=$1} END {print s+0}') || true

if [[ "$AVAIL_MB" -lt 1024 ]]; then
  fail "磁盘空间不足: ${AVAIL_MB}MB 剩余"
elif [[ "$AVAIL_MB" -lt 5120 ]]; then
  warn "磁盘空间偏低: ${AVAIL_MB}MB 剩余"
else
  pass "磁盘空间充足: ${AVAIL_MB}MB 剩余"
fi

info "Build 占用: ${BUILD_SIZE}MB"
[[ "$DERIVED_SIZE" -gt 0 ]] && info "DerivedData 占用: ${DERIVED_SIZE}MB"

# --- 6. 代码风格/安全检查（轻量） ---
echo ""
echo "【代码检查】"

SHELL_SCRIPTS=$(find Scripts -name "*.sh" | wc -l | tr -d ' ')
PASSING_SYNTAX=0
FAILING_SYNTAX=0

while IFS= read -r script; do
  if bash -n "$script" 2>/dev/null; then
    PASSING_SYNTAX=$((PASSING_SYNTAX + 1))
  else
    warn "Shell 脚本语法错误: $script"
    FAILING_SYNTAX=$((FAILING_SYNTAX + 1))
  fi
done < <(find Scripts -name "*.sh" -type f)

if [[ "$FAILING_SYNTAX" -eq 0 ]]; then
  pass "全部 ${SHELL_SCRIPTS} 个 Shell 脚本语法正确"
else
  fail "${FAILING_SYNTAX}/${SHELL_SCRIPTS} 个 Shell 脚本有语法错误"
fi

# --- 7. 汇总报告 ---
echo ""
echo "=============================="
echo " 检查结果: ✅ $PASS 通过 | ⚠️  $WARN 警告 | ❌ $FAIL 失败"
echo "=============================="

TOTAL=$((PASS + FAIL + WARN))

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "建议: 运行 ./Scripts/setup.sh 修复环境问题"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  exit 0
else
  exit 0
fi
