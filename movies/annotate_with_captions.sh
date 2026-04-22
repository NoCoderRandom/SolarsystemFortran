#!/usr/bin/env bash
set -euo pipefail

INPUT_VIDEO="${1:-}"
CAPTION_FILE="${2:-}"
OUTPUT_VIDEO="${3:-}"
FONT_FILE="${FONT_FILE:-/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf}"

if [ "$INPUT_VIDEO" = "--help" ] || [ -z "$INPUT_VIDEO" ] || [ -z "$CAPTION_FILE" ] || [ -z "$OUTPUT_VIDEO" ]; then
    echo "Usage: bash movies/annotate_with_captions.sh <input.mp4> <captions.tsv> <output.mp4>"
    exit 0
fi

if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Missing input video: $INPUT_VIDEO" >&2
    exit 1
fi

if [ ! -f "$CAPTION_FILE" ]; then
    echo "Missing captions file: $CAPTION_FILE" >&2
    exit 1
fi

if [ ! -f "$FONT_FILE" ]; then
    echo "Missing font file: $FONT_FILE" >&2
    exit 1
fi

escape_drawtext() {
    local text="${1:-}"
    text=${text//\\/\\\\}
    text=${text//:/\\:}
    text=${text//,/\\,}
    text=${text//\'/\\\'}
    printf '%s' "$text"
}

filters=(
    "drawbox=x=0:y=ih-172:w=iw:h=172:color=black@0.36:t=fill"
)

while IFS=$'\t' read -r start end headline subline; do
    [ -z "${start:-}" ] && continue
    case "$start" in
        \#*) continue ;;
    esac

    headline_escaped="$(escape_drawtext "$headline")"
    filters+=("drawtext=fontfile=${FONT_FILE}:text='${headline_escaped}':fontsize=34:fontcolor=white:x=(w-text_w)/2:y=h-142:enable='between(t\\,${start}\\,${end})'")

    if [ -n "${subline:-}" ]; then
        subline_escaped="$(escape_drawtext "$subline")"
        filters+=("drawtext=fontfile=${FONT_FILE}:text='${subline_escaped}':fontsize=20:fontcolor=white@0.92:x=(w-text_w)/2:y=h-94:enable='between(t\\,${start}\\,${end})'")
    fi
done < "$CAPTION_FILE"

filter_graph="$(IFS=,; echo "${filters[*]}")"

ffmpeg -y -i "$INPUT_VIDEO" \
    -vf "$filter_graph" \
    -c:v libx265 -preset medium -crf 24 -pix_fmt yuv420p \
    -tag:v hvc1 -movflags +faststart \
    "$OUTPUT_VIDEO"

echo "Captioned video: $OUTPUT_VIDEO"
