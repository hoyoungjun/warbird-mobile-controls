FROM node:22.14.0-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      chromium \
      ffmpeg \
      git \
      fonts-liberation \
      python3 \
      python3-pytest \
 && rm -rf /var/lib/apt/lists/*

# Browser automation is kept outside the checkout so the agent starts from a
# clean upstream tree while the verifier can exercise real touch and layout
# behavior in Chromium.
RUN npm install --prefix /opt/mobile-test --omit=dev --no-audit --no-fund \
      playwright-core@1.51.1

WORKDIR /app

# Upstream 251d6d85cbe5eedbebf7625a8df7fd2430f8d1a1, not visible to agent.
# The agent sees a re-created one-commit repo with hash c35b1b191a9704f51f879a5744b50eb32da4def6
#   which is the one used as "base_commit" in "/tests/config.json".
RUN git clone --filter=blob:none --no-checkout https://github.com/jdubba1/warbird.git /app \
 && git -C /app fetch --depth 1 origin 251d6d85cbe5eedbebf7625a8df7fd2430f8d1a1 \
 && git -C /app -c advice.detachedHead=false checkout FETCH_HEAD \
 && npm run check \
 && { test ! -e /app/.git || git -C /app ls-files --recurse-submodules; } > /tmp/aai-oss-tracked \
 && rm -rf /app/.git /app/.github /app/.gitmodules \
 && find /app -mindepth 2 -name .git -prune -exec rm -rf {} + \
 && git -C /app init -q \
 && while IFS= read -r path; do test -d "/app/$path" || printf '%s\n' "$path"; done < /tmp/aai-oss-tracked | git -C /app update-index --add --remove --stdin \
 && rm /tmp/aai-oss-tracked \
 && git -C /app add -A \
 && GIT_AUTHOR_NAME=scaffold GIT_AUTHOR_EMAIL=scaffold@example.com GIT_AUTHOR_DATE=2000-01-01T00:00:00Z GIT_COMMITTER_NAME=scaffold GIT_COMMITTER_EMAIL=scaffold@example.com GIT_COMMITTER_DATE=2000-01-01T00:00:00Z git -C /app commit -q -m "base" \
 && test "$(git -C /app rev-list --all --count)" -eq 1 \
 && test -z "$(git -C /app remote)" \
 && test ! -e /app/.github \
 && test -z "$(git -C /app status --porcelain)"

ENV CHROME_BIN=/usr/bin/chromium \
    CI=1

RUN mkdir -p /logs/verifier
