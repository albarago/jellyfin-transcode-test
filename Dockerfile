# Jellyfin with the transcoding test (albarago/jellyfin and albarago/jellyfin-web, branch transcode-test),
# built on the official unstable image so jellyfin-ffmpeg and the GPU drivers are the same as upstream.
ARG BASE_IMAGE=jellyfin/jellyfin:unstable

FROM --platform=$BUILDPLATFORM node:24-alpine AS web
RUN apk add --no-cache autoconf g++ make libpng-dev gifsicle alpine-sdk automake libtool gcc musl-dev nasm python3 git
WORKDIR /src
COPY jellyfin-web .
RUN npm ci --no-audit \
 && npm run build:production \
 && mv dist /web

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0 AS server
ARG TARGETARCH
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
WORKDIR /src
COPY jellyfin .
RUN arch="$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo x64)" \
 && dotnet publish Jellyfin.Server --os linux --arch "$arch" --configuration Release \
    --output /server --self-contained -p:DebugSymbols=false -p:DebugType=none

FROM ${BASE_IMAGE}
RUN rm -rf /jellyfin
COPY --from=server /server /jellyfin
COPY --from=web /web /jellyfin/jellyfin-web
LABEL org.opencontainers.image.source="https://github.com/albarago/jellyfin-transcode-test" \
      org.opencontainers.image.title="Jellyfin with the transcoding test" \
      org.opencontainers.image.description="Test build of a proposed Jellyfin feature. Not for production use."
