FROM openclaw-sandbox:ubuntu-24.04-full

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

RUN npm install -g @openai/codex@0.115.0 @zed-industries/codex-acp@0.10.0 mcp-remote@0.1.38

RUN mkdir -p /codex-home \
  && chmod 1777 /codex-home
