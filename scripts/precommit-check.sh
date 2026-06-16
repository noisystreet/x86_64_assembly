#!/bin/bash
# RST 文档预提交检查脚本
# ==========================
# 用法:
#   ./scripts/precommit-check.sh          # 检查所有 RST 文件
#   ./scripts/precommit-check.sh --staged  # 只检查暂存区中的 RST 文件
#   ./scripts/precommit-check.sh --hook    # 作为 git pre-commit hook 运行
#
# 返回码: 0=通过, 1=语法错误, 2=构建警告

set -e

# 确定项目根目录：优先用 git 获取，回退到脚本所在目录的父目录
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
else
    cd "$(dirname "$(readlink -f "$0" || echo "$0")")"
    PROJECT_ROOT="$(cd .. && pwd)"
fi
BUILD_DIR="_build/precommit-check"
EXIT_CODE=0

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_sphinx() {
    if ! python3 -c "import sphinx" 2>/dev/null; then
        echo -e "${RED}错误: 未安装 Sphinx。请先运行: pip install sphinx sphinx-rtd-theme${NC}"
        exit 1
    fi
}

check_rst_inline_markup() {
    local files=("$@")
    local has_error=0

    for f in "${files[@]}"; do
        # 检查 :role:`xxx` 角色标记后紧跟中文括号（缺少空格）
        if grep -Pn ':\w+:`[^`]*`[（）]' "$f" &>/dev/null; then
            if [ $has_error -eq 0 ]; then
                echo -e "${YELLOW}⚠  角色标记后紧跟中文括号（缺少空格）:${NC}"
            fi
            echo -e "  ${YELLOW}$f${NC}"
            grep -Pn ':\w+:`[^`]*`[（）]' "$f" | while read -r line; do
                echo "    $line"
            done
            has_error=1
        fi

        # 检查 **bold** 后紧跟中文括号/逗号（缺少空格）
        if grep -Pn '\*\*[^*]*\*\*[（，]' "$f" &>/dev/null; then
            if [ $has_error -eq 0 ]; then
                echo -e "${YELLOW}⚠  **bold** 后紧跟中文标点（缺少空格）:${NC}"
            fi
            echo -e "  ${YELLOW}$f${NC}"
            grep -Pn '\*\*[^*]*\*\*[（，]' "$f" | while read -r line; do
                echo "    $line"
            done
            has_error=1
        fi
    done

    return $has_error
}

check_rst_files() {
    local files=("$@")
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有 RST 文件需要检查。${NC}"
        return 0
    fi

    echo -e "${YELLOW}检查以下 RST 文件:${NC}"
    for f in "${files[@]}"; do
        echo "  - $f"
    done
    echo ""

    # 在临时目录中构建，避免污染主构建
    rm -rf "$PROJECT_ROOT/$BUILD_DIR"

    echo -e "${YELLOW}运行 Sphinx 语法检查...${NC}"
    # 使用 dummy builder 只做解析不做输出，速度快
    if python3 -m sphinx -b dummy "$PROJECT_ROOT/source" "$PROJECT_ROOT/$BUILD_DIR" 2>/tmp/sphinx_precommit_err.txt 1>/dev/null; then
        # 检查是否有警告
        if grep -qE '(WARNING|ERROR)' /tmp/sphinx_precommit_err.txt 2>/dev/null; then
            echo -e "${YELLOW}⚠  构建成功，但有警告:${NC}"
            grep -E '(WARNING|ERROR)' /tmp/sphinx_precommit_err.txt | while read -r line; do
                echo "  $line"
            done
            EXIT_CODE=2
        else
            echo -e "${GREEN}✓ 所有 RST 文件语法正确，无警告。${NC}"
            EXIT_CODE=0
        fi
    else
        echo -e "${RED}✗ RST 语法错误！请修复以下问题:${NC}"
        cat /tmp/sphinx_precommit_err.txt
        EXIT_CODE=1
    fi

    rm -rf "$PROJECT_ROOT/$BUILD_DIR"
    return $EXIT_CODE
}

# 主逻辑
check_sphinx

if [ "$1" = "--hook" ]; then
    # 作为 git pre-commit hook 运行
    echo -e "${YELLOW}=== Git Pre-Commit Hook: 检查 RST 文档 ===${NC}"

    # 获取暂存区中修改的 .rst 文件
    STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.rst$' || true)

    if [ -z "$STAGED_FILES" ]; then
        echo -e "${GREEN}没有 RST 文件被暂存，跳过检查。${NC}"
        exit 0
    fi

    check_rst_files $STAGED_FILES
    EXIT_CODE=$?

    # 额外检查内联标记格式
    if [ -n "$STAGED_FILES" ]; then
        check_rst_inline_markup $STAGED_FILES && true
    fi

elif [ "$1" = "--staged" ]; then
    # 只检查暂存区文件
    STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.rst$' || true)
    if [ -z "$STAGED_FILES" ]; then
        echo -e "${GREEN}没有 RST 文件被暂存。${NC}"
        exit 0
    fi
    check_rst_files $STAGED_FILES

else
    # 默认: 检查所有 RST 文件
    echo -e "${YELLOW}=== 检查所有 RST 文档 ===${NC}"
    RST_FILES=$(find "$PROJECT_ROOT/source" -name '*.rst' | sort)
    check_rst_files $RST_FILES

    # 额外检查内联标记格式
    check_rst_inline_markup $RST_FILES
fi

case $EXIT_CODE in
    0) echo -e "${GREEN}✓ 检查通过。${NC}" ;;
    2) echo -e "${YELLOW}⚠  检查通过但有警告，建议在提交前修复。${NC}" ;;
    *) echo -e "${RED}✗ 检查未通过。${NC}" ;;
esac
exit $EXIT_CODE
