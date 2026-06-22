#!/usr/bin/env bash
# =============================================================================
# fix-test-imports.sh — 自动将 Testing 框架迁移到 XCTest
#
# 功能：
#   1. import Testing -> import XCTest
#   2. 移除 @Test 属性
#   3. #expect 断言 -> XCTest 等价写法
#
# 用法：
#   ./Scripts/fix-test-imports.sh                    # 测试模式，只显示变更
#   ./Scripts/fix-test-imports.sh --apply             # 实际执行修改
#   ./Scripts/fix-test-imports.sh --apply --dry-run   # 显示将修改的内容
# =============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-preview}"
APPLY=false
DRY_RUN=false

case "$MODE" in
    --apply)
        APPLY=true
        if [[ "${2:-}" == "--dry-run" ]]; then
            DRY_RUN=true
        fi
        ;;
    --dry-run)
        DRY_RUN=true
        ;;
    *)
        echo "🔍 预览模式 — 显示需要修改的文件"
        echo "   使用 --apply 执行实际修改"
        echo ""
        ;;
esac

if $APPLY && ! $DRY_RUN; then
    echo "⚠️  即将执行以下替换："
    echo "   1. import Testing → import XCTest"
    echo "   2. @Test → 移除"
    echo "   3. #expect(…) → XCTAssert*(…)"
    echo ""
    echo "按回车继续，Ctrl+C 取消..."
    read -r
fi

# ---- 统计 ----
total_files=0
total_import=0
total_test_attr=0
total_expect=0

# ---- Step 1: import Testing -> import XCTest ----
echo "━━━ Step 1: import Testing → import XCTest ━━━"
while IFS= read -r -d '' file; do
    if grep -q 'import Testing' "$file"; then
        total_files=$((total_files + 1))
        count=$(grep -c 'import Testing' "$file" || true)
        total_import=$((total_import + count))
        echo "  📄 $file ($count 处)"
        if $APPLY && ! $DRY_RUN; then
            sed -i '' 's/import Testing/import XCTest/g' "$file"
        fi
    fi
done < <(find "$PROJECT_DIR/Tests" -name "*.swift" -type f -print0)

# ---- Step 2: 移除 @Test 属性 ----
echo ""
echo "━━━ Step 2: 移除 @Test 属性 ━━━"
while IFS= read -r -d '' file; do
    if grep -q '@Test' "$file"; then
        count=$(grep -c '@Test' "$file" || true)
        total_test_attr=$((total_test_attr + count))
        echo "  📄 $file ($count 处)"
        if $APPLY && ! $DRY_RUN; then
            # 移除 @Test (支持 @Test func 和 @MainActor @Test 等前置属性组合)
            sed -i '' 's/^[[:space:]]*@Test //' "$file"
            sed -i '' 's/^[[:space:]]*@Test$//' "$file"
        fi
    fi
done < <(find "$PROJECT_DIR/Tests" -name "*.swift" -type f -print0)

# ---- Step 3: #expect -> XCTAssert ----
echo ""
echo "━━━ Step 3: #expect(…) → XCTAssert*(…) ━━━"
while IFS= read -r -d '' file; do
    if grep -q '#expect' "$file"; then
        count=$(grep -c '#expect' "$file" || true)
        total_expect=$((total_expect + count))
        echo "  📄 $file ($count 处)"
        if $APPLY && ! $DRY_RUN; then
            # 注意：以下替换是基础版本，复杂场景（嵌套、多行）需手动检查

            # #expect(Bool(false), "msg") -> XCTFail("msg")
            sed -i '' -E 's/#expect\(Bool\(false\),[[:space:]]*"([^"]*)"\)/XCTFail("\1")/g' "$file"
            # #expect(Bool(true), "msg") -> XCTAssertTrue(true, "msg")
            sed -i '' -E 's/#expect\(Bool\(true\),[[:space:]]*"([^"]*)"\)/XCTAssertTrue(true, "\1")/g' "$file"
            # #expect(Bool(false)) -> XCTFail("")
            sed -i '' 's/#expect(Bool(false))/XCTFail("unexpected false")/g' "$file"
            # #expect(Bool(true)) -> XCTAssertTrue(true)
            sed -i '' 's/#expect(Bool(true))/XCTAssertTrue(true)/g' "$file"

            # #expect(!expr) -> XCTAssertFalse(expr)
            # 注意：嵌套括号问题，这里只处理简单情况
            sed -i '' -E 's/#expect\(!([a-zA-Z_][a-zA-Z0-9_.]*)\)$/XCTAssertFalse(\1)/g' "$file"
            # 带尾随注释或条件
            sed -i '' -E 's/#expect\(!([a-zA-Z_][a-zA-Z0-9_.]*)\)/XCTAssertFalse(\1)/g' "$file"

            # #expect(a == b) -> XCTAssertEqual(a, b)
            # #expect(a != b) -> XCTAssertNotEqual(a, b)
            # 这些模式比较复杂，先做简单的精确匹配替换

            # 兜底：剩余 #expect -> XCTAssertTrue（需要手动检查）
            sed -i '' 's/#expect(/XCTAssertTrue(/g' "$file"
        fi
    fi
done < <(find "$PROJECT_DIR/Tests" -name "*.swift" -type f -print0)

# ---- 汇总 ----
echo ""
echo "━━━ 汇总 ━━━"
echo "   涉及文件: $total_files"
echo "   import Testing → import XCTest: $total_import 处"
echo "   @Test 移除: $total_test_attr 处"
echo "   #expect 替换: $total_expect 处"

if $APPLY && ! $DRY_RUN; then
    echo ""
    echo "✅ 替换完成！"
    echo ""
    echo "⚠️  后续需要手动处理："
    echo "   1. 将测试函数包裹到 XCTestCase 子类中"
    echo "      （参考: docs/testing-standards.md）"
    echo "   2. 检查 #expect 替换结果是否正确"
    echo "   3. 运行 swift build 验证编译"
    echo ""
    echo "💡 自动包裹 XCTestCase 的脚本正在开发中。"
    echo "   当前脚本仅处理 import/@Test/#expect 的基础替换。"
else
    echo ""
    echo "💡 使用 --apply 执行实际修改"
fi
