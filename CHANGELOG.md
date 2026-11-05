# Changelog

Each image is tagged `<server commit>-<web commit>` from the `transcode-test` branches of
[albarago/jellyfin](https://github.com/albarago/jellyfin/tree/transcode-test) and
[albarago/jellyfin-web](https://github.com/albarago/jellyfin-web/tree/transcode-test). `latest` is the newest one.

On 2026-11-02 the `transcode-test` branches were rewritten to correct the commit author name. The files did
not change. Images built before that are tagged with the old commit IDs below; they no longer appear on the
branches.

## `fdb585826-628e429f0` — 2026-11-05
From @EliasV21's re-test on [#163](https://github.com/jellyfin/jellyfin-meta/discussions/163) (RTX 5080, WSL 2).

**Stress test: only ffmpeg's errors are shown as the cause**
- On a 1080p H.264 run, stream 5 hung for 30 s without printing an error. The result quoted a harmless warning about
  the file (`Invalid Block Addition value … type 68766345`, which a dual-layer Dolby Vision remux prints) as if it were
  the cause. The test now runs ffmpeg with `-loglevel +level`, which tags each log line with its level. Only lines at
  error level or worse are shown as the error. This flag changes only ffmpeg's log text, not the transcode: the output
  is byte-for-byte the same with and without it.
- If ffmpeg printed no error, the result now says so: "ffmpeg printed no error." Its last lines stay in the log as
  "Its last output: …", to help diagnose a hang.

**Stress test: no NVIDIA session hint for a stream that hangs**
- Earlier builds added "this may be the driver's limit on encoding sessions" when an NVENC stream never started.
  Real session refusals print an error and exit within about 2 s, and the test now detects those directly as
  **Driver limit**. A silent hang is a different problem, so the hint is gone. The `NvencLimitPossible` field is
  removed from the API.

**What to re-check with this build**
1. Pull the new image (`docker pull ghcr.io/albarago/jellyfin-transcode-test:latest`) and recreate the container.
2. If a stream never started before (e.g. RTX 5080, 1080p H.264): run the same test. The result should say
   "could not start stream N" with either ffmpeg's error or "ffmpeg printed no error", and no NVIDIA hint.
3. While that stream is stuck, run `nvidia-smi` and note the encoder session count, the GPU memory used, and whether
   the encoder and decoder are busy. Please share those with the log line on #163.
4. If you can, run the same test with tone mapping off as well.

## `3e80dc607-102904f34` — 2026-11-04
Fixes from the reports on [#163](https://github.com/jellyfin/jellyfin-meta/discussions/163) by Gauvino, criscrafter
and alyssaholland99.

**Stress test: NVIDIA's session limit is now detected on real cards**
- On drivers that allow 12 sessions (RTX 3060 and 3080), the 13th ffmpeg prints NVIDIA's refusal
  (`OpenEncodeSessionEx failed: incompatible client key (21)`) and then about 10 more error lines. Earlier builds
  kept only the end of that output, so the refusal was gone and the run ended as a plain failed stream. Each line is
  now checked as it arrives, so the run ends as **Driver limit** (`failed_nvenc_limit`), and the refusal is shown
  first in the error text.
- The driver-limit message now says recent drivers allow up to 12 sessions. It used to say 3, 5 or 8.

**Stress test: "GPU memory full"**
- When the GPU runs out of memory after at least one stream kept up, the result is now a warning: "N kept up with
  real time, then the GPU ran out of memory on stream N+1", with ffmpeg's memory error. It no longer shows the NVIDIA
  session hint. Recognised errors: CUDA (`CUDA_ERROR_OUT_OF_MEMORY`), VAAPI (`resource allocation failed`), QSV
  (`failed to allocate memory (-4)`) and Vulkan (`VK_ERROR_OUT_OF_DEVICE_MEMORY`). AMF prints its errors as bare
  numbers, so it isn't recognised yet.
- Not covered yet: every stream freezing at once with no error line (seen on a 10 GB RTX 3080). That one still ends
  as a stalled stream.

**Stress test: same badge for the same cause**
- If the newest stream exits before its first frame after streams kept up (for example exit 218,
  `hwaccel initialisation returned error`), the result is now the orange **Could not add stream** warning, the same as
  when it stalls. It was a red error before.

**What to re-check with this build**
1. Pull the new image (`docker pull ghcr.io/albarago/jellyfin-transcode-test:latest`) and recreate the container.
2. NVIDIA consumer cards (e.g. RTX 3060 on Linux, RTX 3080 on Windows or WSL 2): run the same 1080p stress test. Expect
   **Driver limit** at 12 streams, and the refusal line at the start of the failed stream's log line.
3. Cards that ran out of memory (e.g. RTX 2000 Ada with AV1, Arc A380): run the same test. Expect **GPU memory full**
   with the memory error, and no NVIDIA session hint.
4. A run where the newest stream exited right away (e.g. RTX 2000 Ada HEVC, exit 218): expect the orange
   **Could not add stream** warning.
5. Please share the result banner and the failed stream's log line on #163.

## `1dceda9c5-3cbc4ce19` — 2026-11-03
**Stress test: a stream that never starts is reported as the limit, with ffmpeg's output**
- On an RTX 5080 (NVENC), streams 9 and 10 produced no frames in 30 s while the other 8 ran at about 3× real
  time. The test ended with an error and no clue why. If the newest stream stalls after K streams kept up, the
  result is now a warning: "K stream(s) kept up; the server could not start stream K+1". A stall of the first
  stream, or of one that was already running, is still an error.
- The log and the result now include ffmpeg's last output for a stalled stream (or say that ffmpeg printed
  nothing). Before, that output was dropped.
- If a stalled ffmpeg printed an NVENC session-limit error, the result now says so, like a stream that exits with
  it. With NVENC and 3 or more streams kept up, the banner adds a hint that the NVIDIA driver's session limit may
  be the cause.

**What to re-check with this build**
1. Pull the new image (`docker pull ghcr.io/albarago/jellyfin-transcode-test:latest`) and recreate the container.
2. Run the same stress test as before, once with tone mapping on and once with it off.
3. In the dashboard log, find the line "Stream N produced no frames in 30 s." and the text after it
   ("ffmpeg's last output: …" or "ffmpeg printed nothing."). Please share that line on
   [#163](https://github.com/jellyfin/jellyfin-meta/discussions/163), with the number of streams shown in the
   result banner.

## `d1b62fb38-47e0bdf2f` — 2026-11-03

**Compatibility check: a test clip that can't be made is retried smaller**

- On an Intel Celeron N5095 NAS the AV1 test clip could never be made (`libsvtav1` ended with signal 11), so AV1
  decoding showed **Not tested**. At 1080p, `libsvtav1` needs more than 512 MB, and a container with a tight memory
  limit kills it. If a clip fails, the check now makes it once more at 640×360, which fits in 256 MB, and the log
  says so. The clip only has to exercise the decoder.

**What to re-check with this build**

1. If AV1 decoding showed **Not tested** before, run the compatibility check again. Look for "Trying again at
   640x360" in the log. AV1 decoding should now be tested (on CPUs that can't decode AV1 in hardware, it will
   show as failed or not supported, which is the right answer).
2. If it still can't make the clip, please send the log line, and the container's memory limit if you know it.

## `5d3f71893-47e0bdf2f` — 2026-11-03

Changes suggested on [#163](https://github.com/jellyfin/jellyfin-meta/discussions/163) to follow the Jellyfin
hardware survey's test method ([whitepaper](https://github.com/JPVenson/Jellyfin.HardwareVisualizer/blob/main/HWA-Client-Whitepaper.md)).

**Stress test: every stream must keep real time**

- The threshold is now **100%** of the source frame rate, not 90%. A stream below real time falls further
  behind the longer it plays, until the player runs out of buffer. Short dips are still allowed for 5 seconds.
- **Expect lower counts than with earlier builds.** On an Apple M5 (4K Dolby Vision → 1080p H.264 8 Mbps), 90%
  reported 12 streams, most of them running at 0.91–0.96× real time; 100% reports 8–10. Results from earlier
  builds are not comparable.

**Stress test: speed and single-stream rate**

- A **× real time** column next to each stream's frame rate.
- The result and the test log say how fast **one stream ran alone** (the survey's single-worker speed).

**NVIDIA: the encoding session limit is named**

- Consumer NVIDIA GPUs allow only 3, 5 or 8 encoding sessions at once, depending on the driver. When the driver
  refuses the next one ("out of memory (10)"), the test now ends with **Driver limit** and says it's a driver
  limit, not what the GPU can do. Not yet checked on real NVIDIA hardware: if you have one, please run it.

The API also reports `SurveyFailureReason` (`performance`, `failed_timeout`, `failed_nvenc_limit`), the survey's
names for why a test ended. Unit tests: 74 server, 20 web.

## `4e59508a0-6a1eb6efc` — 2026-11-02

**Compatibility check: tone mapping on macOS is tested the way playback does it**

- The check used to force "Enable VideoToolbox tone mapping" on, so on a Mac it always tested the tone mapping
  built into `scale_vt`. With that option off, playback uses Jellyfin's Metal filter (`tonemap_videotoolbox`)
  instead. The check now keeps your choice, as it already does for VPP on Intel.

**What to re-check with this build (macOS)**

1. Turn "Enable VideoToolbox tone mapping" off, save and run the compatibility check. The tone mapping row should
   test `tonemap_videotoolbox`; with the option on, `scale_vt`.

Checked on an Apple M5 with jellyfin-ffmpeg 8.1.3: off, `tonemap_videotoolbox` passed at 170 fps; on, `scale_vt`
passed at 174 fps. Unit tests: 65 server, 16 web. Same Intel notes as the previous build.

## `3cf182621-66ab809e6` — 2026-11-02

Fixes from a report on an Intel Celeron N5095 (UHD Graphics, i915, TerraMaster TOS 5.1, Portainer), testing QSV
and VAAPI.

**Compatibility check: tone mapping is tested the way playback does it**
- The check used to force "VPP tone mapping" on. Jellyfin's Intel pipelines use VPP (`tonemap_vaapi`) instead of
  OpenCL (`tonemap_opencl`) whenever that option is on, so QSV could fail tone mapping even though playback, with
  VPP off, uses OpenCL. The check now keeps your VPP choice. The filter it tested is shown on the row.

**Compatibility check: encoders run with playback's options**
- The check now passes the same encoder options as playback (preset, profile, level, rate control, Intel
  low-power mode, the i915 workaround). Before, it only set a bitrate, so an encoder could pass or fail differently
  from playback.

**After switching to VAAPI, restart Jellyfin**
- Jellyfin identifies a VAAPI device (Intel iHD, i965 or AMD) only at startup, and only when VAAPI is the saved
  type. Until you restart, it uses its generic VAAPI pipeline, so results can change after a restart. The test log
  now says so when the device has not been identified.

**Clearer reason when a test clip cannot be made**
- SVT-AV1's harmless "Failed to set thread priority" warning is no longer shown as the reason. The log now shows
  the exit code, and the signal if ffmpeg was killed (for example `exit code 137, ended by signal 9`, which
  usually means it ran out of memory).

**What to re-check with this build (Intel QSV / VAAPI)**
1. Restart Jellyfin after every change of hardware acceleration type, then run both tests.
2. QSV with "Enable tone mapping" on and "Enable VPP tone mapping" off: the tone mapping row should test
   `tonemap_opencl`.
3. If the AV1 test clip still cannot be made, please send the new log line with the exit code.

Checked in the tester image (arm64) with an ffmpeg wrapper that makes Jellyfin build its QSV pipeline without a
GPU, and on Apple VideoToolbox. Unit tests: 65 server, 16 web. Not yet run on real Intel hardware.

## `137bc6a5d-66ab809e6` — 2026-11-02

Fixes found while checking the first Intel QSV report (i7-12700K / UHD 770, Unraid, jellyfin-ffmpeg 8.1.3) on
[jellyfin-meta discussion #163](https://github.com/jellyfin/jellyfin-meta/discussions/163).

**Compatibility check: the "Setting" column and the advice**
- HEVC and AV1 encode rows now show **On** only when "Enable hardware encoding" *and* the matching
  "Allow encoding in HEVC / AV1 format" are on. Jellyfin only picks those codecs when they are allowed, but the
  row used to follow the first switch alone, so AV1 showed "On" with "Allow AV1" off.
- A failed encode that is on now says what to turn off. It used to say nothing, unlike decode and tone mapping.
- For HEVC and AV1 the advice names their own checkbox (**Turn off “Allow encoding in AV1 format”**), not
  "Enable hardware encoding", which would also stop H.264 encoding on the GPU.
- The check never advises turning on "Allow HEVC / AV1". Whether to allow them depends on your clients, not on
  your hardware. It only advises turning on "Enable hardware encoding" when that switch is off.
- A failed check for a setting that is already off now reads "Your hardware may not support this. It's off in
  your settings, so there is nothing to change." instead of "ffmpeg failed:". The ffmpeg error is still shown
  below it.

**Compatibility check: a failure is blamed on the part that was tested**
- Each decode check also encodes, and each encode check also decoded. A broken hardware encoder made decoding look
  broken, and a broken hardware decoder made every encode row fail. Now the encode check decodes on the CPU, and a
  failed decode check runs once more with the CPU encoder (the test log says so). Only a decoder that still fails
  is reported as failed.

**What to re-check with this build**
1. Rows for formats your GPU lacks and that are off in your settings (for example VP8 decode, AV1 encode on Intel
   UHD 770) should show the calm wording and no advice.
2. Turn on "Allow encoding in AV1 format", save and run again. If AV1 still fails, the advice should name that
   checkbox.
3. Look in the test log for "Trying again with the CPU encoder". If a decode row was *Failed* before and is *Works*
   now, the failure was the encoder's. Please send the log.

Not covered: telling "the hardware does not have this" from "this is broken" for certain needs driver capability
data (see jellyfin-ffmpeg PR #733).

Tested with a wrapper that makes only the hardware decoder, or only the hardware encoder, fail (Apple
VideoToolbox), and with unit tests (54 server, 16 web). Not yet run on Intel, NVIDIA or AMD hardware.

## `7b1331354-66ab809e6` — 2026-11-02

First three fixes above (the "Setting" column, the advice, the calm wording). Superseded by the next build.

## Earlier builds — 2026-11-01 and the morning of 2026-11-02

First test builds: the compatibility check and the stress test on the Transcoding page.
