FROM node:22.14.0-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      chromium \
      git \
      fonts-liberation \
 && rm -rf /var/lib/apt/lists/*

# Browser automation is kept outside the checkout so the agent starts from a
# clean upstream tree while the verifier can exercise real touch and layout
# behavior in Chromium.
RUN npm install --prefix /opt/mobile-test --omit=dev --no-audit --no-fund \
      playwright-core@1.51.1

WORKDIR /app

RUN git clone --filter=blob:none --no-checkout https://github.com/jdubba1/warbird.git /app \
 && git -C /app fetch --depth 1 origin 251d6d85cbe5eedbebf7625a8df7fd2430f8d1a1 \
 && git -C /app -c advice.detachedHead=false checkout FETCH_HEAD \
 && npm run check

ENV CHROME_BIN=/usr/bin/chromium \
    CI=1

RUN mkdir -p /logs/verifier
