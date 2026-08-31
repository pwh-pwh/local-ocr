#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SKILL_DIR"

echo "== local-ocr doctor =="

if [[ ! -x engine/target/release/local-ocr-engine && ! -x bin/local-ocr-engine ]]; then
  echo "编译引擎（首次需要 cmake/clang，约 1–2 分钟）..."
  if ! command -v cargo >/dev/null; then
    echo "缺少 cargo/rustc" >&2
    exit 1
  fi
  cargo build --release --manifest-path engine/Cargo.toml
  mkdir -p bin
  cp -f engine/target/release/local-ocr-engine bin/local-ocr-engine
else
  echo "引擎二进制已就绪"
  if [[ -x engine/target/release/local-ocr-engine && ! -x bin/local-ocr-engine ]]; then
    mkdir -p bin
    cp -f engine/target/release/local-ocr-engine bin/local-ocr-engine
  fi
fi

echo "检查 tiny 模型..."
bash scripts/download-models.sh tiny

echo "OK  入口: $SKILL_DIR/scripts/ocr"
echo "    模型: ${LOCAL_OCR_MODELS:-$HOME/.cache/ocr-rs/models}"
