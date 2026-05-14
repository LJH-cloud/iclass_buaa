#!/bin/bash

set -e

echo "开始初始化环境..."

# 检查 node 是否安装
if ! [ -x "$(command -v node)" ]; then
  echo "错误: 本机未安装 Node.js，请先安装。" >&2
  exit 1
fi

if ! [ -x "$(command -v npm)" ]; then
  echo "错误: 本机未安装 npm，请先安装 Node.js（含 npm）。" >&2
  exit 1
fi

hash_file() {
  if [ -x "$(command -v shasum)" ]; then
    shasum -a 256 "$1" | awk "{print \$1}"
  else
    sha256sum "$1" | awk "{print \$1}"
  fi
}

deps_fingerprint() {
  local dir="$1"
  local result=""
  local file=""
  for file in package-lock.json package.json; do
    if [ -f "$dir/$file" ]; then
      result="${result}${file}:$(hash_file "$dir/$file");"
    fi
  done
  echo "$result"
}

ensure_deps() {
  local dir="$1"
  local name="$2"
  local marker="$dir/node_modules/.deps-fingerprint"
  local current=""
  local cached=""

  current="$(deps_fingerprint "$dir")"

  if [ "${FORCE_INSTALL:-0}" = "1" ]; then
    echo "[$name] 检测到 FORCE_INSTALL=1，执行强制安装..."
  elif [ -d "$dir/node_modules" ] && [ -f "$marker" ]; then
    cached="$(cat "$marker" 2>/dev/null || true)"
    if [ "$cached" = "$current" ]; then
      echo "[$name] 依赖未变化，跳过安装。"
      return 0
    fi
  fi

  echo "[$name] 正在安装/更新依赖，请稍候..."
  (cd "$dir" && npm install --no-audit --no-fund)
  mkdir -p "$dir/node_modules"
  printf "%s" "$current" > "$marker"
  echo "[$name] 依赖安装完成。"
}

# 1. 安装依赖（仅在依赖变化时执行）
ensure_deps "." "root"
ensure_deps "./client" "client"
ensure_deps "./server" "server"

echo "环境已就绪。"

# 2. 询问是否立即启动（直接回车默认启动）
read -p "是否立即启动应用? (Y/n): " confirm
confirm="${confirm:-y}"
confirm="$(printf "%s" "$confirm" | tr '[:upper:]' '[:lower:]')"
if [ "$confirm" = "y" ] || [ "$confirm" = "yes" ]; then
  # 使用 npm run dev 启动 concurrently 管理的复合命令
  npm run dev
fi
