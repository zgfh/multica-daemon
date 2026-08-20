FROM node:22-slim

# 基础工具 + Claude Code（也可以按需换成 codex / opencode 等其他 agent CLI）
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git openssh-client bash \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code

# 直接从官方 GitHub Release 拉编译好的二进制（而不是跑第三方脚本），
# 资产命名规则：multica-cli-{version}-{os}-{arch}.tar.gz（例如 multica-cli-0.4.30-linux-amd64.tar.gz）
# 版本号按需固定，避免镜像内容随 main 分支更新漂移；升级时手动改这里
ARG MULTICA_CLI_VERSION=0.4.30
RUN curl -fsSL -o /tmp/multica.tar.gz \
      "https://github.com/multica-ai/multica/releases/download/v${MULTICA_CLI_VERSION}/multica-cli-${MULTICA_CLI_VERSION}-linux-amd64.tar.gz" \
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
