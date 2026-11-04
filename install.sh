#!/usr/bin/env bash
# Ambient Dashboard — Übersicht widget installer
# 用法：在解压出来的 ambient-dashboard 目录里执行  bash install.sh
set -euo pipefail

NAME="ambient-dashboard"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${UEBERSICHT_WIDGETS:-$HOME/Library/Application Support/Übersicht/widgets}"
TARGET="$DEST/$NAME"

if [ "$SRC" = "$TARGET" ]; then
  echo "已经在 widgets 目录里了，无需安装。"
  exit 0
fi

if [ ! -d "$HOME/Library/Application Support/Übersicht" ] && [ -z "${UEBERSICHT_WIDGETS:-}" ]; then
  echo "没找到 Übersicht（~/Library/Application Support/Übersicht）。"
  echo "先安装：https://tracesof.net/uebersicht/"
  echo "装好后重新执行本脚本；或设置 UBERSICHT_WIDGETS 指向自定义目录。"
  exit 1
fi

mkdir -p "$DEST"

if [ -e "$TARGET" ]; then
  BACKUP="$TARGET.bak.$(date +%Y%m%d-%H%M%S)"
  mv "$TARGET" "$BACKUP"
  echo "已存在旧版本，备份到：$BACKUP"
fi

cp -R "$SRC" "$TARGET"
rm -rf "$TARGET/.git"
find "$TARGET" -name '.DS_Store' -delete 2>/dev/null || true
chmod +x "$TARGET/get-data.sh"

echo
echo "已安装到：$TARGET"
echo
echo "接下来两步（都只做一次）："
echo "  1. 菜单栏 Übersicht 图标 → Refresh All Widgets"
echo "  2. 首次刷新会弹窗询问「控制 System Events / Music」，必须点允许；"
echo "     另需在 系统设置 → 隐私与安全 → 完全磁盘访问权限 里勾上 Übersicht（读专辑封面缓存用）"
echo
echo "自检：bash \"\$HOME/Library/Application Support/Übersicht/widgets/$NAME/get-data.sh\""
