#!/usr/bin/env bash
set -euo pipefail

TIER="${1:-tiny}"
case "$TIER" in
  tiny|small|medium) ;;
  *) echo "档位: tiny | small | medium" >&2; exit 2 ;;
esac

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib.sh
source "$SKILL_DIR/scripts/lib.sh"
DEST="$(default_models_dir)"
BASE="${OCR_RS_MODEL_BASE:-https://raw.githubusercontent.com/zibo-chen/rust-paddle-ocr/next/models}"
mkdir -p "$DEST"

files=(
  "PP-OCRv6_${TIER}_det.mnn"
  "PP-OCRv6_${TIER}_rec.mnn"
  "ppocr_keys_v6_${TIER}.txt"
)

echo "下载 PP-OCRv6 $TIER → $DEST"
for name in "${files[@]}"; do
  dest="$DEST/$name"
  if [[ -s "$dest" ]]; then
    echo "已存在: $name"
    continue
  fi
  echo "获取: $name"
  curl -fL --retry 3 -o "$dest" "$BASE/$name"
done
echo "完成。"
