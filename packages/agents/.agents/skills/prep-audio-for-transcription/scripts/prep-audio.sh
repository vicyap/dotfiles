#!/usr/bin/env bash
# Trim long silences, compress to speech-grade mono AAC, and split into parts
# under the size limit. Outputs land beside each source file; a source whose
# outputs already exist is skipped, never overwritten.
set -euo pipefail
shopt -s nullglob

limit_bytes="${PREP_AUDIO_LIMIT_BYTES:-24000000}"
skipped=0

if [[ $# -eq 0 ]]; then
    echo "usage: prep-audio.sh <audio-file>..." >&2
    exit 64
fi

for src in "$@"; do
    if [[ ! -f "$src" ]]; then
        echo "missing: $src" >&2
        exit 66
    fi

    stem="${src%.*}"
    out="$stem - trimmed.m4a"
    existing=("$stem - trimmed.m4a" "$stem - trimmed part"[0-9][0-9].m4a)
    if [[ -e "${existing[0]}" || ${#existing[@]} -gt 1 ]]; then
        echo "skipped, output exists: $src" >&2
        skipped=1
        continue
    fi

    # Pauses over 1s shrink to 0.5s; -45dB keeps quiet speech.
    ffmpeg -hide_banner -loglevel error -n -i "$src" \
        -af "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.3:stop_periods=-1:stop_duration=1.0:stop_threshold=-45dB:stop_silence=0.5,aresample=16000" \
        -ac 1 -c:a aac -b:a 48k "$out"

    size=$(stat -f %z "$out" 2>/dev/null || stat -c %s "$out")
    duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")
    src_duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$src")

    if ((size <= limit_bytes)); then
        printf '%s\t%s bytes\t%.0fs (from %.0fs)\n' "$out" "$size" "$duration" "$src_duration"
        continue
    fi

    parts=$(((size + limit_bytes - 1) / limit_bytes))
    segment_time=$(awk -v d="$duration" -v p="$parts" 'BEGIN { print int(d / p) + 1 }')
    ffmpeg -hide_banner -loglevel error -n -i "$out" -c copy -map 0:a \
        -f segment -segment_time "$segment_time" -segment_start_number 1 -reset_timestamps 1 \
        "$stem - trimmed part%02d.m4a"
    rm -f "$out"

    for part in "$stem - trimmed part"[0-9][0-9].m4a; do
        part_size=$(stat -f %z "$part" 2>/dev/null || stat -c %s "$part")
        part_duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$part")
        printf '%s\t%s bytes\t%.0fs\n' "$part" "$part_size" "$part_duration"
    done
done

exit "$skipped"
