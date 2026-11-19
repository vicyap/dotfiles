---
name: prep-audio-for-transcription
description: >-
  Prepare local audio recordings for transcription: trim long silences,
  compress to 16 kHz mono AAC, and split into parts under 25 MB at silences.
  Use when the user asks to trim, compress, shrink, or split recordings (m4a,
  mp3, wav, and similar) for a transcription service or upload limit, or
  invokes /prep-audio-for-transcription with file paths.
---

# Prep audio for transcription

Use the bundled scripts; do not write ffmpeg commands by hand. Both need
`ffmpeg` and `ffprobe`.

## Prepare recordings

Run once with every file the user named:

```bash
~/.agents/skills/prep-audio-for-transcription/scripts/prep-audio.sh [options] <file>...
```

For each source it writes, beside the source:

- `<name> - trimmed.m4a` when the result fits under the limit, or
- `<name> - trimmed part01.m4a`, `part02`, ... when it does not.

It never overwrites: a source with any existing output is skipped with a
message on stderr, and the script exits 1 after processing the rest. To redo a
source, ask the user before deleting its earlier outputs.

It prints one line per output: path, size in bytes, duration, and the source
time range it covers.

What it does:

- Splits before trimming. It finds silences of at least `--split-silence`
  seconds (default 2) in the source and ends each part at the middle of the
  last such silence that keeps the part under the limit, so no word is cut.
  If a stretch has no such silence, it cuts at the limit, the next part
  repeats the last 3 s, and the output line says so.
- Trims each part: pauses longer than 1 s at or below `--threshold` dB
  (default -45) shrink to 0.5 s, so speaker turns stay audible and quiet speech
  is kept.
- Encodes mono, 16 kHz, AAC 48 kbps (about 21 MB per hour), which loses nothing
  speech-to-text models use.
- Keeps each file under `--limit` bytes (default 24,000,000, under 25 MB in
  decimal or binary units). Parts are sized from source duration, so they come
  out smaller than the limit after trimming.

Options:

- `--threshold DB`: level counted as silence for both trimming and split
  points. Raise it (for example -35) to trim more on a noisy recording, at a
  small risk of clipping quiet words.
- `--split-silence SEC`: shortest silence a split may cut inside.
- `--limit BYTES`: maximum file size.

## Tune for a recording

When the user wants more trimmed, or the output reports hard cuts, survey the
recording first:

```bash
~/.agents/skills/prep-audio-for-transcription/scripts/find-silences.sh <file> [min-seconds] [dB...]
```

It prints, per threshold (default -50 to -30 in 5 dB steps), the number of
silences at least `min-seconds` long (default 2), their total length, and the
longest. Pick the lowest threshold that finds enough silences, then rerun
`prep-audio.sh` with it on a source whose outputs the user has agreed to
delete.

## Report

Give each output path with its size and duration, how much silence was removed
(source duration minus total output duration), and any hard cuts.
