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
    MINGW*|MSYS*|CYGWIN*)
      echo "x86_64-pc-windows-msvc"
      ;;
    *)
      echo ""
      ;;
  esac
}

engine_filename() {
  local target="$1"
  if [[ "$target" == *windows* ]]; then
    echo "local-ocr-engine-${target}.exe"
  else
    echo "local-ocr-engine-${target}"
  fi
}

read_release_tag() {
  local ver
  ver="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$SKILL_DIR/engine/Cargo.toml" | head -1)"
  echo "v${ver}"
}
