# Jellyfin transcoding test: test build

A Docker image of Jellyfin with a proposed **Compatibility check** and **Stress test** on the
Dashboard -> Playback -> Transcoding page:

- **Compatibility check:** checks which video formats your GPU decodes and encodes with your saved settings, and
  whether HDR tone mapping works, using short test clips it creates. It tells you which settings to change.

  <img width="971" height="782" alt="compatibility-check" src="https://github.com/user-attachments/assets/45f944fd-c8dd-4ce0-a979-16e836b9267d" />

- **Stress test:** transcodes a movie the way Jellyfin does during playback and adds a stream every 12 seconds
  until one can no longer keep up with real time (100% of the source frame rate). It also reports how fast one
  stream runs alone, and on NVIDIA it tells you if the driver's session limit was hit.

  <img width="971" height="782" alt="stress-test" src="https://github.com/user-attachments/assets/7bd1cce9-6f6d-4ce9-94c8-e8dc66d9f478" />

The code is in the `transcode-test` branches of [albarago/jellyfin](https://github.com/albarago/jellyfin/tree/transcode-test)
and [albarago/jellyfin-web](https://github.com/albarago/jellyfin-web/tree/transcode-test). The proposal and
discussion are in [jellyfin-meta #163](https://github.com/jellyfin/jellyfin-meta/discussions/163).

So far it has been tested on Apple VideoToolbox, Intel (UHD 770, Celeron N5095, Arc A380) and one AMD GPU
(Vega 7). **NVIDIA** results are the most useful now, followed by more **AMD** cards.

See [CHANGELOG.md](CHANGELOG.md) for what changed between builds and what to re-check.

This is a development build of Jellyfin 13.0, not a release. Run it **next to** your real server, never on your
real server's config.

## 1. Start it

Use a new, empty config and mount one media folder read-only. That way nothing your real server uses is touched.

```sh
docker pull ghcr.io/albarago/jellyfin-transcode-test:latest
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

## 1b. Or build it yourself (Windows and macOS, no Docker)

> [!WARNING]
> This is a Jellyfin 13.0 dev build. **Never** point it at your real server's data folder. It will upgrade
> your database, and that can't be undone. Always use a separate `--datadir`, as shown below.
>
> | OS | Real server's data folder (don't use it) |
> |---|---|
> | Windows | `C:\ProgramData\Jellyfin\Server` |
> | macOS | `~/Library/Application Support/jellyfin` |

**Install these once:** [Git](https://git-scm.com/), [.NET SDK 10.0](https://dotnet.microsoft.com/download/dotnet/10.0)
and [Node.js 24+](https://nodejs.org/). For ffmpeg, reuse the one from your real Jellyfin install, or download
the portable build for your OS from [jellyfin-ffmpeg releases](https://github.com/jellyfin/jellyfin-ffmpeg/releases).

**Stop your real server first.** Both use port 8096.

| OS | To stop | To start again |
|---|---|---|
| Windows, service | `Stop-Service JellyfinServer` (admin PowerShell) | `Start-Service JellyfinServer` |
| Windows, tray app | Right-click the tray icon -> Exit | Open Jellyfin Server from Start |
| macOS | Click the Jellyfin menu bar icon -> Quit | Open Jellyfin from Applications |

### Windows (PowerShell, in an empty folder like `C:\jf-test`)

```powershell
git clone -b transcode-test https://github.com/albarago/jellyfin-web; cd jellyfin-web; npm ci; npm run build:production; cd ..
git clone -b transcode-test https://github.com/albarago/jellyfin; dotnet build -c Release jellyfin/Jellyfin.Server

dotnet run -c Release --no-build --project jellyfin/Jellyfin.Server -- --webdir "$PWD\jellyfin-web\dist" --ffmpeg "C:\Program Files\Jellyfin\Server\ffmpeg.exe" --datadir "$PWD\test-data"
```

### macOS (Terminal, in an empty folder like `~/jf-test`)

```sh
git clone -b transcode-test https://github.com/albarago/jellyfin-web && cd jellyfin-web && npm ci && npm run build:production && cd ..
git clone -b transcode-test https://github.com/albarago/jellyfin && dotnet build -c Release jellyfin/Jellyfin.Server

dotnet run -c Release --no-build --project jellyfin/Jellyfin.Server -- --webdir "$PWD/jellyfin-web/dist" --ffmpeg "/Applications/Jellyfin.app/Contents/MacOS/ffmpeg" --datadir "$PWD/test-data"
```

If your ffmpeg is somewhere else, change the `--ffmpeg` path. Then open `http://localhost:8096` and continue
with step 2. On macOS, pick **VideoToolbox** as the hardware acceleration.

**To restart it** (step 2 needs this): press `Ctrl+C`, then run the `dotnet run` line again.

**To update it:** stop it, then run this in the same folder and start it again:

```sh
git -C jellyfin-web pull; git -C jellyfin pull
cd jellyfin-web; npm ci; npm run build:production; cd ..
dotnet build -c Release jellyfin/Jellyfin.Server
```

**To remove it:** stop it, start your real server again, and delete the folder (`C:\jf-test` or `~/jf-test`).

## 2. Run the tests

1. Open `http://<your server>:8097`, create an admin user, and add a library pointing at `/media`.
2. Go to **Dashboard -> Playback -> Transcoding**, choose your hardware acceleration as you would on your real
   server, and click **Save**.
3. **Restart Jellyfin** (Docker: `docker restart jellyfin-transcode-test`; built yourself: `Ctrl+C`, then run it
   again). Jellyfin only identifies the GPU at startup, so do this every time you change the hardware
   acceleration type.
4. Scroll to the bottom and click **Run compatibility check**. The first run takes longer while it makes the
   test clips.
5. Under **Stress test**, choose a demanding movie (a 4K HDR file is best), keep **1080p H.264 8 Mbps**, and click
   **Start stress test**. It takes a few minutes. Make sure nobody is watching on your real server, because both
   share the GPU.

## 3. Share the results

Post them in [jellyfin-meta #163](https://github.com/jellyfin/jellyfin-meta/discussions/163). Please include:

- your CPU, GPU, OS and driver version, and the hardware acceleration type you chose;
- when your image was built: `docker image inspect --format '{{.Created}}' ghcr.io/albarago/jellyfin-transcode-test:latest`;
- screenshots of the compatibility check table and the stress test result;
- the **Test log** of each test (expand it at the bottom of each section and copy the text);
- anything that looked wrong or was confusing.

## 4. Update it

Your config and library are kept in the volumes, so you only need to replace the container:

```sh
docker pull ghcr.io/albarago/jellyfin-transcode-test:latest
docker rm -f jellyfin-transcode-test
```

Then run the `docker run` command from step 1 again.

## 5. Remove it

```sh
docker rm -f jellyfin-transcode-test
docker volume rm jellyfin-transcode-test-config jellyfin-transcode-test-cache
```

## Building the image

GitHub Actions builds it for `linux/amd64` and `linux/arm64` (Actions -> Image -> Run workflow). The Dockerfile
replaces the server and web client of the official `jellyfin/jellyfin:unstable` image with the two branches.
