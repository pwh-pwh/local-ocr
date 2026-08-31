#!/usr/bin/env bash
# 准备引擎和 tiny 模型。优先用仓库预编译包 / GitHub Release，没有才本地 cargo 编译。
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib.sh
source "$SKILL_DIR/scripts/lib.sh"
cd "$SKILL_DIR"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

TARGET="$(detect_target)"
TAG="$(read_release_tag)"
REPO="${LOCAL_OCR_RELEASE_REPO:-pwh-pwh/rapid-ocr}"
DEST_DIR="$SKILL_DIR/bin"
EXT=""
[[ "$TARGET" == *windows* ]] && EXT=".exe"
DEST="$DEST_DIR/local-ocr-engine${EXT}"
ASSET="$(engine_filename "$TARGET")"
PREBUILT_DIR="$SKILL_DIR/prebuilt/$TARGET"
PREBUILT="$PREBUILT_DIR/local-ocr-engine${EXT}"

echo "== local-ocr doctor =="
echo "平台: ${TARGET:-unknown}  版本: $TAG"

need_engine=0
if [[ "$FORCE" -eq 1 || ! -x "$DEST" ]]; then
  need_engine=1
fi

verify_sha() {
  local dir="$1" file="$2"
  local sum="$dir/${file}.sha256"
  [[ -f "$sum" ]] || return 0
  if command -v sha256sum >/dev/null; then
    (cd "$dir" && sha256sum -c "$(basename "$sum")")
  elif command -v shasum >/dev/null; then
    (cd "$dir" && shasum -a 256 -c "$(basename "$sum")")
  fi
}

install_from_prebuilt() {
  [[ -n "$TARGET" && -x "$PREBUILT" ]] || return 1
  echo "使用仓库预编译包: $PREBUILT"
  verify_sha "$PREBUILT_DIR" "local-ocr-engine${EXT}"
  mkdir -p "$DEST_DIR"
  cp -f "$PREBUILT" "$DEST"
  chmod +x "$DEST"
}

download_release() {
  [[ -n "$TARGET" ]] || return 1
  command -v curl >/dev/null || return 1
  local url tmp
  tmp="$(mktemp)"
  mkdir -p "$DEST_DIR"
  for url in \
    "${LOCAL_OCR_RELEASE_BASE:-https://github.com/${REPO}/releases/download/${TAG}}/${ASSET}" \
    "https://github.com/${REPO}/releases/latest/download/${ASSET}"
  do
    echo "尝试下载: $url"
    if curl -fL --retry 3 -o "$tmp" "$url"; then
      chmod +x "$tmp"
      mv -f "$tmp" "$DEST"
      echo "已安装 $DEST"
      return 0
    fi
  done
  rm -f "$tmp"
  return 1
}

build_from_source() {
  if ! command -v cargo >/dev/null; then
    return 1
  fi
  echo "预编译包不可用，本地编译引擎（需要 cmake/clang，约 1–2 分钟）..."
  cargo build --release --manifest-path engine/Cargo.toml
  mkdir -p "$DEST_DIR"
  local built="engine/target/release/local-ocr-engine${EXT}"
  cp -f "$built" "$DEST"
  chmod +x "$DEST"
}

if [[ "$need_engine" -eq 1 ]]; then
  if install_from_prebuilt; then
    :
  elif download_release; then
    :
  elif build_from_source; then
    :
  else
    echo "无法准备引擎。" >&2
    echo "请任选其一：" >&2
    echo "  1. 从 https://github.com/${REPO}/releases 下载 ${ASSET} 放到 bin/" >&2
    echo "  2. 安装 rustc/cargo + cmake + clang 后重跑本脚本" >&2
    echo "  3. 设置 LOCAL_OCR_BIN 指向已有二进制" >&2
    exit 1
  fi
else
  echo "引擎已就绪: $DEST"
fi

echo "检查 tiny 模型..."
bash "$SKILL_DIR/scripts/download-models.sh" tiny

echo "OK  入口: $SKILL_DIR/scripts/ocr"
echo "    引擎: $DEST"
echo "    模型: ${LOCAL_OCR_MODELS:-$HOME/.cache/ocr-rs/models}"
echo "无需长期安装 Rust。"
