# Jellyfin transcoding test: test build

A test build of Jellyfin with a proposed **Compatibility check** and **Stress test** on the
Dashboard -> Playback -> Transcoding page:

- **Compatibility check:** checks which video formats your GPU decodes and encodes with your saved settings, and
  whether HDR tone mapping works, using short test clips it creates. It tells you which settings to change.

  <img width="971" height="782" alt="compatibility-check" src="https://github.com/user-attachments/assets/45f944fd-c8dd-4ce0-a979-16e836b9267d" />

- **Stress test:** transcodes a movie the way Jellyfin does during playback and adds a stream every 12 seconds
  until one can no longer keep up with real time (100% of the source frame rate). It also reports how fast one
  stream runs alone, and on NVIDIA it reports when NVENC refuses a new encoding session, with the diagnostic
  needed to investigate the cause.

  <img width="971" height="782" alt="stress-test" src="https://github.com/user-attachments/assets/7bd1cce9-6f6d-4ce9-94c8-e8dc66d9f478" />

The code is in the `transcode-test` branches of [albarago/jellyfin](https://github.com/albarago/jellyfin/tree/transcode-test)
and [albarago/jellyfin-web](https://github.com/albarago/jellyfin-web/tree/transcode-test). The proposal and
discussion are in [jellyfin-meta #163](https://github.com/jellyfin/jellyfin-meta/discussions/163).

So far it has been tested on Apple VideoToolbox, Intel (UHD 770, Celeron N5095, Arc A380) and one AMD GPU
(Vega 7). **NVIDIA** results are the most useful now, followed by more **AMD** cards.

See [CHANGELOG.md](CHANGELOG.md) for what changed between builds and what to re-check.

> [!WARNING]
> This is a development build of Jellyfin 13.0, not a release. Run it **next to** your real server, never on
> your real server's config or data folder. It would upgrade your database, and that can't be undone.

## 1. Start it

Pick one:

- **Docker** (Linux, Unraid, NAS, etc.): see [1A](#1a-docker).
- **Build it yourself** (native Windows or macOS): see [1B](#1b-build-it-yourself-windows-and-macos).

Both run the test server on port **8097**, so your real server on 8096 can keep running.

### 1A. Docker

Use a new, empty config and mount one media folder read-only. That way nothing your real server uses is touched.

```sh
docker pull ghcr.io/albarago/jellyfin-transcode-test:latest
docker run -d --name jellyfin-transcode-test -p 127.0.0.1:8097:8096 \
  -v jellyfin-transcode-test-config:/config \
  -v jellyfin-transcode-test-cache:/cache \
  -v /path/to/some/movies:/media:ro \
  <GPU option> \
  ghcr.io/albarago/jellyfin-transcode-test:latest
```

The published port is host-local by default: open `http://localhost:8097` on the Docker host.
For a NAS or another machine on your LAN, opt in to remote access with an SSH tunnel from your own computer:

```sh
ssh -N -L 127.0.0.1:8097:127.0.0.1:8097 <user>@<docker-host>
```

Then open `http://localhost:8097` on your computer. A direct LAN port publication would also expose the test
server's first-run setup to other clients on that network; it is not enabled by these examples. Keep the test
server private and finish creating its administrator account before sharing access.

| GPU | `<GPU option>` |
|---|---|
| Intel or AMD (VA-API, Quick Sync) | `--device /dev/dri:/dev/dri --group-add "$(getent group render \| cut -d: -f3)"` |
| NVIDIA | `--gpus all` (needs the NVIDIA Container Toolkit) |

**NVIDIA inside a Proxmox LXC container.** If `docker run` fails with
`nvidia-container-cli: mount error: failed to add device rules: ... bpf_prog_query(BPF_CGROUP_DEVICE) failed: operation not permitted`,
Docker can't manage the GPU's device rules from inside the container. Set `no-cgroups = true` in
`/etc/nvidia-container-runtime/config.toml`, then pass the device nodes yourself in place of `<GPU option>`:

```sh
--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all \
  --device /dev/nvidia0 --device /dev/nvidiactl --device /dev/nvidia-uvm --device /dev/nvidia-uvm-tools
```

### 1B. Build it yourself (Windows and macOS)

**Never** use your real server's data folder for the test server:

| OS | Real server's data folder (don't use it) |
|---|---|
| Windows | `C:\ProgramData\Jellyfin\Server` |
| macOS | `~/Library/Application Support/jellyfin` |

**Install these once:** [Git](https://git-scm.com/), [.NET SDK 10.0](https://dotnet.microsoft.com/download/dotnet/10.0)
and [Node.js 24+](https://nodejs.org/). For ffmpeg, reuse the one from your real Jellyfin install, or download
the portable build for your OS from [jellyfin-ffmpeg releases](https://github.com/jellyfin/jellyfin-ffmpeg/releases).

#### Windows (PowerShell, in an empty folder like `C:\jf-test`)

Build it:

```powershell
git clone -b transcode-test https://github.com/albarago/jellyfin-web; cd jellyfin-web; npm ci; npm run build:production; cd ..
git clone -b transcode-test https://github.com/albarago/jellyfin; dotnet build -c Release jellyfin/Jellyfin.Server
```

Set it to port 8097 (once, before the first start):

```powershell
New-Item -ItemType Directory -Force test-data\config | Out-Null
Set-Content test-data\config\network.xml '<?xml version="1.0" encoding="utf-8"?><NetworkConfiguration><InternalHttpPort>8097</InternalHttpPort><LocalNetworkAddresses><string>127.0.0.1</string></LocalNetworkAddresses><EnableAutoDiscovery>false</EnableAutoDiscovery></NetworkConfiguration>'
```

Start it:

```powershell
dotnet run -c Release --no-build --project jellyfin/Jellyfin.Server -- --webdir "$PWD\jellyfin-web\dist" --ffmpeg "C:\Program Files\Jellyfin\Server\ffmpeg.exe" --datadir "$PWD\test-data" --configdir "$PWD\test-data\config"
```

#### macOS (Terminal, in an empty folder like `~/jf-test`)

Build it:

```sh
git clone -b transcode-test https://github.com/albarago/jellyfin-web && cd jellyfin-web && npm ci && npm run build:production && cd ..
git clone -b transcode-test https://github.com/albarago/jellyfin && dotnet build -c Release jellyfin/Jellyfin.Server
```

Set it to port 8097 (once, before the first start):

```sh
mkdir -p test-data/config
echo '<?xml version="1.0" encoding="utf-8"?><NetworkConfiguration><InternalHttpPort>8097</InternalHttpPort><LocalNetworkAddresses><string>127.0.0.1</string></LocalNetworkAddresses><EnableAutoDiscovery>false</EnableAutoDiscovery></NetworkConfiguration>' > test-data/config/network.xml
```

Start it:

```sh
dotnet run -c Release --no-build --project jellyfin/Jellyfin.Server -- --webdir "$PWD/jellyfin-web/dist" --ffmpeg "/Applications/Jellyfin.app/Contents/MacOS/ffmpeg" --datadir "$PWD/test-data" --configdir "$PWD/test-data/config"
```

If your ffmpeg is somewhere else, change the `--ffmpeg` path. To stop it, press `Ctrl+C`.

<details>
<summary>Prefer to stop your real server and use port 8096 instead?</summary>

Use the same separate `test-data/config/network.xml`, changing `InternalHttpPort` to `8096` and keeping
`LocalNetworkAddresses` set to `127.0.0.1`. Stop your real server, then open `http://localhost:8096` in step 2.

| OS | To stop | To start again |
|---|---|---|
| Windows, service | `Stop-Service JellyfinServer` (admin PowerShell) | `Start-Service JellyfinServer` |
| Windows, tray app | Right-click the tray icon -> Exit | Open Jellyfin Server from Start |
| macOS | Click the Jellyfin menu bar icon -> Quit | Open Jellyfin from Applications |

</details>

## 2. Run the tests

1. Open `http://localhost:8097` (use the SSH tunnel above for a remote Docker host), create an admin user,
   and add a library with one movie folder (`/media` on Docker).
2. Go to **Dashboard -> Playback -> Transcoding**, choose your hardware acceleration as you would on your real
   server (VideoToolbox on a Mac), and click **Save**.
3. **Restart the test server.** Docker: `docker restart jellyfin-transcode-test`. Built yourself: `Ctrl+C`, then
   run the start command again. Jellyfin only identifies the GPU at startup, so do this every time you change the
   hardware acceleration type.
4. Scroll to the bottom and click **Run compatibility check**. The first run takes longer while it makes the
   test clips.
5. Under **Stress test**, choose a demanding movie (a 4K HDR file is best), keep **1080p H.264 8 Mbps**, and click
   **Start stress test**. It takes a few minutes. Make sure nobody is watching on your real server, because both
   share the GPU.

## 3. Share the results

Post them in [jellyfin-meta #163](https://github.com/jellyfin/jellyfin-meta/discussions/163). Please include:

- your CPU, GPU, OS and driver version, and the hardware acceleration type you chose;
- which build you ran. Docker: `docker inspect --format '{{.Image}}' jellyfin-transcode-test` identifies the running
  container's image even if `latest` has moved; share it together with
  `docker inspect --format '{{json .Config.Labels}}' jellyfin-transcode-test` (the full server, web and image-recipe
  revisions and the pinned bases are recorded there).
  Built yourself: `git -C jellyfin log -1 --format=%h` and `git -C jellyfin-web log -1 --format=%h`;
- screenshots of the compatibility check table and the stress test result;
- the **Test log** of each test (expand it at the bottom of each section and copy the text);
- anything that looked wrong or was confusing.

## 4. Update it

Your settings and library are kept, so you only need the new code.

Docker:

```sh
docker pull ghcr.io/albarago/jellyfin-transcode-test:latest
docker rm -f jellyfin-transcode-test
```

Then run the `docker run` command from 1A again.

Built yourself: stop it, then in the same folder run:

```sh
git -C jellyfin-web pull; git -C jellyfin pull
cd jellyfin-web; npm ci; npm run build:production; cd ..
dotnet build -c Release jellyfin/Jellyfin.Server
```

Then start it again with the start command from 1B.

## 5. Remove it

Docker:

```sh
docker rm -f jellyfin-transcode-test
docker volume rm jellyfin-transcode-test-config jellyfin-transcode-test-cache
```

Built yourself: stop it and delete the folder (`C:\jf-test` or `~/jf-test`). If you stopped your real server,
start it again.

## Building the image

GitHub Actions builds it for `linux/amd64` and `linux/arm64` (Actions -> Image -> Run workflow). The Dockerfile
replaces the server and web client of the official `jellyfin/jellyfin:unstable` image with the two branches.

All three base images are pinned to multi-platform index digests, and all workflow actions are pinned to full
commit IDs. Each build records the full checked-out server, web and image-repository revisions in image labels
and the Actions summary, together with the pinned bases and published image digest. BuildKit provenance and SBOM
attestations are requested as well.

The existing `<server commit>-<web commit>` tag is kept as a convenience alias, but a third tag,
`<server commit>-<web commit>-<image recipe commit>`, distinguishes a Dockerfile/workflow change built from the
same source pair. `latest` and the two-commit alias can move; use the published image **digest** for an exact
artifact. Local builds should pass `SERVER_REVISION`, `WEB_REVISION` and `IMAGE_REVISION` as build arguments using
the full `git rev-parse HEAD` output for each checkout, otherwise their revision labels read `unknown`.

These pins identify the sources and base images; they do not promise byte-for-byte reproducibility. `apk add`
still resolves packages from live Alpine repositories, NuGet restore can contact package feeds, and the runner,
QEMU and BuildKit can change independently of the action code. npm uses the checked-in lockfile, and changing a
base pin or action pin requires reviewing its upstream contents and supported architectures again.
