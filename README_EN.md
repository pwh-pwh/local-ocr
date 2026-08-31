# local-ocr

Local Chinese OCR skill using [ocr-rs](https://crates.io/crates/ocr-rs) (PaddleOCR PP-OCRv6 + MNN).

**No Rust install required** for normal use. Apache License 2.0.

## Setup

Place this directory on the Agent skills path, then:

```bash
bash scripts/doctor.sh
scripts/ocr photo.jpg
```

Windows (PowerShell, no Git Bash / Rust required):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1
powershell -ExecutionPolicy Bypass -File scripts\ocr.ps1 photo.jpg
```

`doctor` uses, in order:

1. `prebuilt/<target>/` (Linux x86_64 is in git)
2. GitHub Releases, including **Windows x64 `.exe`**
3. Local `cargo build` only if neither is available

Models: `~/.cache/ocr-rs/models/` on Unix, `%LOCALAPPDATA%\ocr-rs\models` on Windows.
