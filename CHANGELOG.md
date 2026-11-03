# Changelog

Each image is tagged `<server commit>-<web commit>` from the `transcode-test` branches of
[albarago/jellyfin](https://github.com/albarago/jellyfin/tree/transcode-test) and
[albarago/jellyfin-web](https://github.com/albarago/jellyfin-web/tree/transcode-test). `latest` is the newest one.

On 2026-11-02 the `transcode-test` branches were rewritten to correct the commit author name. The files did
not change. Images built before that are tagged with the old commit IDs below; they no longer appear on the
branches.

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
