# Jellyfin with the transcoding test (albarago/jellyfin and albarago/jellyfin-web, branch transcode-test),
# built on the official unstable image, so jellyfin-ffmpeg and the GPU drivers are those of that upstream build.
# The bases are pinned to multi-platform index digests (linux/amd64 and linux/arm64, verified 2026-11-15); bump the
# pins to follow newer upstream builds.
ARG BASE_IMAGE=jellyfin/jellyfin:unstable@sha256:95e37bb3f338fe93d3ced30c25d930abe817baecddaa8495727c3e9080fd0d8b
ARG NODE_IMAGE=node:24-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5
ARG DOTNET_SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:10.0@sha256:fe0fd4e93bd2fbb47c883b7a6369e5c8d3db8bf01cdc5981f6ee35fbdf3ff4fb

FROM --platform=$BUILDPLATFORM ${NODE_IMAGE} AS web
RUN apk add --no-cache autoconf g++ make libpng-dev gifsicle alpine-sdk automake libtool gcc musl-dev nasm python3 git
WORKDIR /src
COPY jellyfin-web .
RUN npm ci --no-audit \
 && npm run build:production \
 && mv dist /web

FROM --platform=$BUILDPLATFORM ${DOTNET_SDK_IMAGE} AS server
ARG TARGETARCH
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
WORKDIR /src
COPY jellyfin .
RUN arch="$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo x64)" \
 && dotnet publish Jellyfin.Server --os linux --arch "$arch" --configuration Release \
    --output /server --self-contained -p:DebugSymbols=false -p:DebugType=none

FROM ${BASE_IMAGE}
ARG BASE_IMAGE
ARG NODE_IMAGE
ARG DOTNET_SDK_IMAGE
ARG SERVER_REVISION=unknown
ARG WEB_REVISION=unknown
ARG IMAGE_REVISION=unknown
RUN rm -rf /jellyfin
COPY --from=server /server /jellyfin
COPY --from=web /web /jellyfin/jellyfin-web
LABEL org.opencontainers.image.source="https://github.com/albarago/jellyfin-transcode-test" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.title="Jellyfin with the transcoding test" \
      org.opencontainers.image.description="Test build of a proposed Jellyfin feature. Not for production use." \
      io.github.albarago.transcode-test.source.server="https://github.com/albarago/jellyfin" \
      io.github.albarago.transcode-test.revision.server="${SERVER_REVISION}" \
      io.github.albarago.transcode-test.source.web="https://github.com/albarago/jellyfin-web" \
      io.github.albarago.transcode-test.revision.web="${WEB_REVISION}" \
      io.github.albarago.transcode-test.base.runtime="${BASE_IMAGE}" \
      io.github.albarago.transcode-test.base.web="${NODE_IMAGE}" \
      io.github.albarago.transcode-test.base.sdk="${DOTNET_SDK_IMAGE}"
