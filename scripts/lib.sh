# shellcheck shell=bash
# sourced by doctor.sh

detect_target() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Linux)
      case "$arch" in
        x86_64) echo "x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) echo "aarch64-unknown-linux-gnu" ;;
        *) echo "" ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64) echo "x86_64-apple-darwin" ;;
        arm64) echo "aarch64-apple-darwin" ;;
        *) echo "" ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      echo "x86_64-pc-windows-msvc"
      ;;
    *)
      echo ""
      ;;
  esac
}

default_models_dir() {
  if [[ -n "${LOCAL_OCR_MODELS:-}" ]]; then
    echo "$LOCAL_OCR_MODELS"
    return
  fi
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      echo "${LOCALAPPDATA:-$HOME/AppData/Local}/ocr-rs/models"
      ;;
    *)
      echo "${XDG_CACHE_HOME:-$HOME/.cache}/ocr-rs/models"
      ;;
  esac
}

engine_candidates() {
  local root="$1"
  echo "$root/bin/local-ocr-engine.exe"
  echo "$root/bin/local-ocr-engine"
  echo "$root/engine/target/release/local-ocr-engine.exe"
  echo "$root/engine/target/release/local-ocr-engine"
}

engine_filename() {
  local target="$1"
  if [[ "$target" == *windows* ]]; then
    echo "local-ocr-engine-${target}.exe"
  else
    echo "local-ocr-engine-${target}"
  fi
}

run_python() {
  if command -v python3 >/dev/null; then
    python3 "$@"
  elif command -v py >/dev/null; then
    py -3 "$@"
  else
    python "$@"
  fi
}

read_release_tag() {
  local ver
  ver="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$SKILL_DIR/engine/Cargo.toml" | head -1)"
  echo "v${ver}"
}
