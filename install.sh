#!/bin/bash

# 安装脚本

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${YELLOW}安装 Dual AI Workflow...${NC}"
echo ""

# 检查是否已经在 PATH 中
if command -v workflow &> /dev/null; then
    echo -e "${GREEN}✓ workflow 命令已在 PATH 中${NC}"
    workflow help
    exit 0
fi

# 创建软链接
if [[ -d "$HOME/.local/bin" ]]; then
    ln -sf "${SCRIPT_DIR}/bin/workflow" "$HOME/.local/bin/workflow"
    echo -e "${GREEN}✓ 已创建软链接到 ~/.local/bin/workflow${NC}"
elif [[ -d "/usr/local/bin" ]]; then
    sudo ln -sf "${SCRIPT_DIR}/bin/workflow" "/usr/local/bin/workflow"
    echo -e "${GREEN}✓ 已创建软链接到 /usr/local/bin/workflow${NC}"
else
    echo -e "${YELLOW}警告: 未找到合适的 bin 目录${NC}"
    echo "请手动添加到 PATH:"
    echo "  export PATH=\"${SCRIPT_DIR}/bin:\$PATH\""
    exit 1
fi

# 安装 skill
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "${SKILLS_DIR}"
ln -sf "${SCRIPT_DIR}/.skills/workflow" "${SKILLS_DIR}/dual-ai-workflow"
echo -e "${GREEN}✓ 已安装 /workflow skill 到 ~/.claude/skills/${NC}"

# 验证安装
if command -v workflow &> /dev/null; then
    echo ""
    echo -e "${GREEN}✓ 安装成功！${NC}"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  1. 命令行工具: workflow <command>"
    echo "  2. Claude Code Skill: /workflow <task-description> <executor>"
    echo ""
    workflow help
else
    echo -e "${YELLOW}安装可能失败，请检查 PATH 配置${NC}"
fi
