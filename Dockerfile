FROM node:22-slim

# 基础工具 + Claude Code + claude-code-router
# ccr 替代 cc-switch（GTK GUI），纯 CLI/服务化，做 OpenAI -> Anthropic 协议转换
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git openssh-client bash \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code @musistudio/claude-code-router

# 直接从官方 GitHub Release 拉编译好的二进制，
# 资产命名规则：multica-cli-{version}-{os}-{arch}.tar.gz
# 使用 TARGETARCH 自动匹配构建架构（amd64/arm64）
# 版本号按需固定，避免镜像内容随 main 分支更新漂移；升级时手动改这里
ARG MULTICA_CLI_VERSION=0.4.30
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64) MULTICA_ARCH=amd64 ;; \
      arm64) MULTICA_ARCH=arm64 ;; \
      *) echo "unsupported arch: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/multica.tar.gz \
       "https://github.com/multica-ai/multica/releases/download/v${MULTICA_CLI_VERSION}/multica-cli-${MULTICA_CLI_VERSION}-linux-${MULTICA_ARCH}.tar.gz" \
    && tar -xzf /tmp/multica.tar.gz -C /tmp \
    && mv /tmp/multica /usr/local/bin/multica \
    && chmod +x /usr/local/bin/multica \
    && rm -f /tmp/multica.tar.gz

# 专用非 root 用户跑 daemon，任务权限限制在这个用户能读写的范围内
RUN useradd -m -s /bin/bash multica
USER multica
WORKDIR /home/multica

# daemon 的任务工作目录，配合下面 K8s 里的 PVC 挂载
ENV MULTICA_WORKSPACES_ROOT=/home/multica/workspaces
RUN mkdir -p /home/multica/workspaces

COPY --chown=multica:multica entrypoint.sh /home/multica/entrypoint.sh
RUN chmod +x /home/multica/entrypoint.sh

ENTRYPOINT ["/home/multica/entrypoint.sh"]
