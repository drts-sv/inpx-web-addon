# Multi-stage: collect the glass-theme fork, then run it on a plain Node runtime.
# The upstream release binary embeds its own untouched front-end, so the runtime
# must be `node server` with our dist/public.json — not the pkg binary.

FROM node:20-bookworm-slim AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates zip \
 && rm -rf /var/lib/apt/lists/*

# Pinned fork revision of the UI (drts-sv/inpx-web-glass). Bump to refresh.
ARG GLASS_REF=fd81e20

RUN git clone https://github.com/drts-sv/inpx-web-glass /src \
 && cd /src \
 && git checkout "${GLASS_REF}"

WORKDIR /src

RUN npm ci --ignore-scripts --no-audit --no-fund
RUN npx webpack --config build/webpack.prod.config.js
# packs dist/tmp/public into dist/public.json (needs the `zip` binary)
RUN node build/prepkg.js linux

FROM node:20-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates jq \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /src/package.json /src/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund

COPY --from=build /src/server ./server
COPY --from=build /src/build ./build
COPY --from=build /src/dist/public.json ./dist/public.json

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
