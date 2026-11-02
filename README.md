# Jellyfin transcoding test: test build

A Docker image of Jellyfin with a proposed **Compatibility check** and **Stress test** on the
Dashboard → Playback → Transcoding page:

- **Compatibility check:** checks which video formats your GPU decodes and encodes with your saved settings, and
  whether HDR tone mapping works, using short test clips it creates. It tells you which settings to change.

<img width="971" height="782" alt="compatibility-check" src="https://github.com/user-attachments/assets/45f944fd-c8dd-4ce0-a979-16e836b9267d" />

  
- **Stress test:** transcodes a movie the way Jellyfin does during playback and adds a stream every 12 seconds
  until one can no longer keep up with real time.

  <img width="971" height="782" alt="stress-test" src="https://github.com/user-attachments/assets/7bd1cce9-6f6d-4ce9-94c8-e8dc66d9f478" />


The code is in the `transcode-test` branches of [albarago/jellyfin](https://github.com/albarago/jellyfin/tree/transcode-test)
and [albarago/jellyfin-web](https://github.com/albarago/jellyfin-web/tree/transcode-test). It has only been tested on
Apple VideoToolbox so far. Results from **NVIDIA, Intel and AMD** hardware are the most useful.

See [CHANGELOG.md](CHANGELOG.md) for what changed between builds and what to re-check.

This is a development build of Jellyfin 13.0, not a release. Run it **next to** your real server, never on your
real server's config.

## 1. Start it

Use a new, empty config and mount one media folder read-only. That way nothing your real server uses is touched.

```sh
docker run -d --name jellyfin-transcode-test -p 8097:8096 \
  -v jellyfin-transcode-test-config:/config \
  -v jellyfin-transcode-test-cache:/cache \
  -v /path/to/some/movies:/media:ro \
  <GPU option> \
  ghcr.io/albarago/jellyfin-transcode-test:latest
```

| GPU | `<GPU option>` |
|---|---|
| Intel or AMD (VA-API, Quick Sync) | `--device /dev/dri:/dev/dri --group-add "$(getent group render \| cut -d: -f3)"` |
| NVIDIA | `--gpus all` (needs the NVIDIA Container Toolkit) |

## 2. Run the tests

1. Open `http://<your server>:8097`, create an admin user, and add a library pointing at `/media`.
2. Go to **Dashboard → Playback → Transcoding**, choose your hardware acceleration as you would on your real
   server, and click **Save**.
3. Scroll to the bottom and click **Run compatibility check**.
4. Under **Stress test**, choose a demanding movie (a 4K HDR file is best), keep **1080p H.264 8 Mbps**, and click
   **Start stress test**. It takes a few minutes. Make sure nobody is watching on your real server, because both
   share the GPU.

## 3. Share the results

Please include:

- your CPU, GPU, OS and driver version, and the hardware acceleration type you chose;
- screenshots of the compatibility check table and the stress test result;
- the **Test log** of each test (expand it at the bottom of each section and copy the text);
- anything that looked wrong or was confusing.

## 4. Remove it

```sh
docker rm -f jellyfin-transcode-test
docker volume rm jellyfin-transcode-test-config jellyfin-transcode-test-cache
```

## Building the image

GitHub Actions builds it for `linux/amd64` and `linux/arm64` (Actions → Image → Run workflow). The Dockerfile
replaces the server and web client of the official `jellyfin/jellyfin:unstable` image with the two branches.
