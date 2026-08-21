#!/bin/bash
set -euo pipefail

: "${MULTICA_SERVER_URL:?need MULTICA_SERVER_URL, e.g. https://api.multica.c.daozzg.com}"
: "${MULTICA_APP_URL:?need MULTICA_APP_URL, e.g. https://multica.c.daozzg.com}"
: "${MULTICA_TOKEN:?need MULTICA_TOKEN, a personal access token (mul_ prefix) from Settings -> Personal Access Tokens}"

# ── ccr (claude-code-router) 配置 ──
# 如果 CCR_PROVIDER_API_BASE_URL 设置了，就启动 ccr 本地代理
# Claude Code 通过 ANTHROPIC_BASE_URL 指向 ccr，不直连 Anthropic
CCR_PORT=3456

if [ -n "${CCR_PROVIDER_API_BASE_URL:-}" ]; then
  : "${CCR_PROVIDER_API_KEY:?need CCR_PROVIDER_API_KEY when CCR_PROVIDER_API_BASE_URL is set}"
  : "${CCR_PROVIDER_NAME:=openai-upstream}"
  : "${CCR_PROVIDER_MODELS:=gpt-4o}"
  : "${CCR_DEFAULT_MODEL:=openai-upstream,gpt-4o}"

  # 生成 ccr 配置文件
  mkdir -p "$HOME/.claude-code-router"
  cat > "$HOME/.claude-code-router/config.json" <<CCR_CONFIG
{
  "Providers": [
    {
      "name": "${CCR_PROVIDER_NAME}",
      "api_base_url": "${CCR_PROVIDER_API_BASE_URL}",
      "api_key": "${CCR_PROVIDER_API_KEY}",
      "models": ["$(echo "${CCR_PROVIDER_MODELS}" | sed 's/,/","/g')"]
    }
  ],
  "Router": {
    "default": "${CCR_DEFAULT_MODEL}"
  }
}
CCR_CONFIG

  # 后台启动 ccr 代理
  ccr start >/tmp/ccr.log 2>&1 &
  sleep 2

  # Claude Code 指向本地 ccr 代理，不需要直连 Anthropic
  export ANTHROPIC_BASE_URL="http://127.0.0.1:${CCR_PORT}"
  export ANTHROPIC_AUTH_TOKEN="ccr-proxy"
else
  # 未配置 ccr 时，直连 Anthropic，需要 API key
  : "${ANTHROPIC_API_KEY:?need ANTHROPIC_API_KEY for Claude Code (or set CCR_PROVIDER_API_BASE_URL to use ccr proxy)}"
fi

multica config set server_url "$MULTICA_SERVER_URL"
multica config set app_url "$MULTICA_APP_URL"

# 无头/令牌登录，跳过浏览器 OAuth 流程
multica login --token "$MULTICA_TOKEN"

# 前台运行，容器主进程即 daemon，方便 k8s 探活和日志采集
exec multica daemon start --foreground
