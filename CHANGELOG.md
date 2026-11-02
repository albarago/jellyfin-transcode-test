# Changelog

Each image is tagged `<server commit>-<web commit>` from the `transcode-test` branches of
[albarago/jellyfin](https://github.com/albarago/jellyfin/tree/transcode-test) and
[albarago/jellyfin-web](https://github.com/albarago/jellyfin-web/tree/transcode-test). `latest` is the newest one.

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
