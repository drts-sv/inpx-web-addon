FROM debian:bookworm-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# The release binary is a pkg-packed Node app linked against glibc
# (PT_INTERP = ld-linux-x86-64.so.2 / ld-linux-aarch64.so.1), so the base image
# must be Debian-based, not alpine.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip jq libstdc++6 \
 && rm -rf /var/lib/apt/lists/*

# TARGETARCH is provided by buildkit: amd64 | arm64.
# No ${BUILD_FROM} / bashio here on purpose: the Supervisor did not pass
# build.args for this local app, and a self-contained base removes that whole
# failure mode.
ARG TARGETARCH=amd64
ARG INPX_VERSION=1.5.8

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) ZIP="inpx-web-${INPX_VERSION}-linux.zip" ;; \
        arm64) ZIP="inpx-web-${INPX_VERSION}-linux-arm64.zip" ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/inpx.zip \
        "https://github.com/bookpauk/inpx-web/releases/download/${INPX_VERSION}/${ZIP}"; \
    mkdir -p /opt/inpx-web; \
    unzip -q /tmp/inpx.zip -d /opt/inpx-web; \
    rm -f /tmp/inpx.zip /opt/inpx-web/readme.html; \
    chmod +x /opt/inpx-web/inpx-web; \
    echo "=== inpx-web installed: $(du -h /opt/inpx-web/inpx-web | cut -f1) ==="

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
