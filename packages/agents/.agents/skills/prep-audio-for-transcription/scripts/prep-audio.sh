#!/usr/bin/env bash
# Trim long silences, compress to speech-grade mono AAC, and split into parts
# under the size limit, cutting inside silences. Outputs land beside each
# source file; a source whose outputs already exist is skipped, never
# overwritten.
set -euo pipefail
shopt -s nullglob

usage() {
    cat >&2 <<'USAGE'
usage: prep-audio.sh [options] <audio-file>...
  --threshold DB       level counted as silence, in dB (default -45; -35 trims more)
  --split-silence SEC  shortest silence a split may cut inside (default 2)
  --limit BYTES        maximum bytes per output file (default 24000000)
USAGE
    exit 64
}

threshold=-45
split_silence=2
limit_bytes=24000000
while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold)
            threshold="$2"
            shift 2
            ;;
        --split-silence)
            split_silence="$2"
            shift 2
            ;;
        --limit)
            limit_bytes="$2"
            shift 2
            ;;
        -h | --help) usage ;;
        --)
            shift
            break
            ;;
        -*)
            echo "unknown option: $1" >&2
            usage
            ;;
        *) break ;;
    esac
done
[[ $# -gt 0 ]] || usage

# 48 kbps AAC measures about 6,240 bytes per second; 6,500 leaves headroom.
max_span=$((limit_bytes / 6500))
trim_filter="silenceremove=start_periods=1:start_threshold=${threshold}dB:start_silence=0.3:stop_periods=-1:stop_duration=1.0:stop_threshold=${threshold}dB:stop_silence=0.5,aresample=16000"
skipped=0

file_size() { stat -f %z "$1" 2>/dev/null || stat -c %s "$1"; }
duration_of() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

for src in "$@"; do
    if [[ ! -f "$src" ]]; then
        echo "missing: $src" >&2
        exit 66
    fi

    stem="${src%.*}"
    existing=("$stem - trimmed.m4a" "$stem - trimmed part"[0-9][0-9].m4a)
    if [[ -e "${existing[0]}" || ${#existing[@]} -gt 1 ]]; then
        echo "skipped, output exists: $src" >&2
        skipped=1
        continue
    fi

    src_duration=$(duration_of "$src")

    # Each line is "start end [hard]" of one part in source time. Silences are
    # found before trimming, which shrinks them. A part ends at the middle of
    # the last long-enough silence that keeps it within max_span; with none it
    # is cut hard and the next part repeats the last 3 s.
    ranges=$(ffmpeg -hide_banner -nostats -i "$src" -af "silencedetect=n=${threshold}dB:d=${split_silence}" -f null - 2>&1 \
        | awk -v total="$src_duration" -v span="$max_span" '
            /silence_start:/ { s = $NF }
            /silence_end:/ { for (i = 1; i <= NF; i++) if ($i == "silence_end:") cuts[n++] = (s + $(i + 1)) / 2 }
            END {
                start = 0
                while (total - start > span) {
                    best = -1
                    for (i = 0; i < n; i++) if (cuts[i] > start && cuts[i] <= start + span) best = cuts[i]
                    if (best < 0) {
                        printf "%.3f %.3f hard\n", start, start + span
                        start = start + span - 3
                    } else {
                        printf "%.3f %.3f\n", start, best
                        start = best
                    }
                }
                printf "%.3f %.3f\n", start, total
            }')

    count=$(wc -l <<<"$ranges" | tr -d ' ')
    index=0
    while read -r start end hard; do
        index=$((index + 1))
        if ((count == 1)); then
            out="$stem - trimmed.m4a"
        else
            out=$(printf '%s - trimmed part%02d.m4a' "$stem" "$index")
        fi
        ffmpeg -hide_banner -loglevel error -nostdin -n -ss "$start" -to "$end" -i "$src" \
            -af "$trim_filter" -ac 1 -c:a aac -b:a 48k "$out"
        note=""
        if [[ -n "${hard:-}" ]]; then
            note=" (no ${split_silence} s silence in range; hard cut, next part repeats 3 s)"
        fi
        printf '%s\t%s bytes\t%.0fs (source %.0f-%.0fs)%s\n' \
            "$out" "$(file_size "$out")" "$(duration_of "$out")" "$start" "$end" "$note"
    done <<<"$ranges"
done

exit "$skipped"
