#!/usr/bin/env bash
# Report how many silences prep-audio.sh would see at each threshold, to pick
# --threshold and --split-silence for a recording.
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: find-silences.sh <audio-file> [min-seconds (default 2)] [dB...] (default -50 -45 -40 -35 -30)" >&2
    exit 64
fi

src="$1"
min="${2:-2}"
shift $(($# < 2 ? $# : 2))
levels=("$@")
[[ ${#levels[@]} -gt 0 ]] || levels=(-50 -45 -40 -35 -30)

printf 'dB\tsilences>=%ss\ttotal silent s\tlongest s\n' "$min"
for db in "${levels[@]}"; do
    ffmpeg -hide_banner -nostats -nostdin -i "$src" -af "silencedetect=n=${db}dB:d=${min}" -f null - 2>&1 \
        | awk -v db="$db" '
            /silence_duration:/ { d = $NF; n++; t += d; if (d > m) m = d }
            END { printf "%s\t%d\t%.1f\t%.1f\n", db, n, t, m }'
done
