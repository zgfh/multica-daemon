#!/bin/bash
set -euo pipefail

: "${MULTICA_SERVER_URL:?need MULTICA_SERVER_URL, e.g. https://api.multica.c.daozzg.com}"
: "${MULTICA_APP_URL:?need MULTICA_APP_URL, e.g. https://multica.c.daozzg.com}"
: "${MULTICA_TOKEN:?need MULTICA_TOKEN, a personal access token (mul_ prefix) from Settings -> Personal Access Tokens}"

# Claude Code 自身的鉴权（按你用的 agent CLI 替换/追加）
: "${ANTHROPIC_API_KEY:?need ANTHROPIC_API_KEY for Claude Code}"

multica config set server_url "$MULTICA_SERVER_URL"
multica config set app_url "$MULTICA_APP_URL"

# 无头/令牌登录，跳过浏览器 OAuth 流程
multica login --token "$MULTICA_TOKEN"

# 前台运行，容器主进程即 daemon，方便 k8s 探活和日志采集
exec multica daemon start --foreground
