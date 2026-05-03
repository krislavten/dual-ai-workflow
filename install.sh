#!/bin/bash

# Sparring 安装脚本
# 装两个命令：sparring (主) 和 workflow (兼容别名)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${YELLOW}安装 Sparring...${NC}"
echo ""

# 选择目标目录
target_dir=""
sudo_cmd=""
if [[ -d "$HOME/.local/bin" ]]; then
    target_dir="$HOME/.local/bin"
elif [[ -d "/usr/local/bin" ]]; then
    target_dir="/usr/local/bin"
    sudo_cmd="sudo"
else
    echo -e "${YELLOW}警告: 未找到合适的 bin 目录${NC}"
    echo "请手动添加到 PATH:"
    echo "  export PATH=\"${SCRIPT_DIR}/bin:\$PATH\""
    exit 1
fi

# 创建软链接 — sparring 主命令 + workflow 兼容别名
$sudo_cmd ln -sf "${SCRIPT_DIR}/bin/sparring" "${target_dir}/sparring"
$sudo_cmd ln -sf "${SCRIPT_DIR}/bin/sparring" "${target_dir}/workflow"
echo -e "${GREEN}✓ 已安装到 ${target_dir}/${NC}"
echo -e "${GREEN}  主命令: sparring${NC}"
echo -e "${GREEN}  兼容别名: workflow (原命令名，仍可用)${NC}"

# 安装 Claude Code skill
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "${SKILLS_DIR}"
ln -sf "${SCRIPT_DIR}/.skills/workflow" "${SKILLS_DIR}/sparring"
echo -e "${GREEN}✓ 已安装 sparring skill 到 ~/.claude/skills/${NC}"

# 验证
if command -v sparring &> /dev/null; then
    echo ""
    echo -e "${GREEN}✓ 安装成功${NC}"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  1. 命令行: sparring <command>  (或 workflow <command>)"
    echo "  2. Claude Code Skill: /sparring <task-description>"
    echo ""
    sparring help
else
    echo -e "${YELLOW}安装可能失败，请检查 PATH 配置${NC}"
fi
