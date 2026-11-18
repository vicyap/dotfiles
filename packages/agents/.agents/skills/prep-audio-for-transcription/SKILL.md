---
name: prep-audio-for-transcription
description: >-
  Prepare local audio recordings for transcription: trim long silences,
  compress to 16 kHz mono AAC, and split into parts under 25 MB. Use when the
  user asks to trim, compress, shrink, or split recordings (m4a, mp3, wav,
  and similar) for a transcription service or upload limit, or invokes
  /prep-audio-for-transcription with file paths.
---

# Prep audio for transcription

Run the bundled script with every file the user named, in one call:

```bash
~/.agents/skills/prep-audio-for-transcription/scripts/prep-audio.sh <file>...
```

It requires `ffmpeg` and `ffprobe`. For each source it writes, beside the
source:

- `<name> - trimmed.m4a` when the result is under the limit, or
- `<name> - trimmed part01.m4a`, `part02`, ... of roughly equal length when
  it is not. The single trimmed file is removed after splitting.

It prints one line per output: path, size in bytes, and duration. It never
overwrites: a source with any existing output is skipped with a message on
stderr, and the script exits 1 after processing the rest. To redo a source,
ask the user before deleting its earlier outputs.

Settings:

- Silence: pauses longer than 1 s at or below -45 dB shrink to 0.5 s, so speaker
  turns stay audible and quiet speech is kept.
- Encoding: mono, 16 kHz, AAC 48 kbps (about 21 MB per hour), which loses
  nothing speech-to-text models use.
- Limit: 24,000,000 bytes per file, under 25 MB in either decimal or binary
  units. Override with `PREP_AUDIO_LIMIT_BYTES`.
- Splits fall at fixed time points, not at silences, so a word at a boundary
  may be cut.

Report each output path with its size and duration, and how much silence was
removed (source duration minus output duration). If the user wants more
trimmed, rerun ffmpeg with a higher threshold such as -35 dB, warning that it
can clip quiet words.
