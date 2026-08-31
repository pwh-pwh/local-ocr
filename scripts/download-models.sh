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

if models_ready "$DEST" "$TIER"; then
  exit 0
fi

echo "下载 PP-OCRv6 $TIER → $DEST"
while IFS= read -r name; do
  dest="$DEST/$name"
  if model_file_ok "$dest"; then
    echo "已存在: $name"
    continue
  fi
  echo "获取: $name"
  tmp="$dest.part"
  rm -f "$tmp"
  if ! curl -fL --retry 3 -o "$tmp" "$BASE/$name"; then
    rm -f "$tmp"
    echo "下载失败: $name" >&2
    exit 1
  fi
  if ! model_file_ok "$tmp" "$name"; then
    rm -f "$tmp"
    echo "下载不完整: $name" >&2
    exit 1
  fi
  mv -f "$tmp" "$dest"
done < <(model_names "$TIER")
echo "完成。"
