# local-ocr

Local Chinese OCR skill using [ocr-rs](https://crates.io/crates/ocr-rs) (PaddleOCR PP-OCRv6 + MNN).

**No Rust install required** for normal use. Apache License 2.0.

## Setup

Place this directory on the Agent skills path, then:

```bash
bash scripts/doctor.sh
# or just:
scripts/ocr photo.jpg
```

`doctor.sh` uses, in order:

1. `prebuilt/<target>/` in this repo (Linux x86_64 is included)
2. GitHub Releases: https://github.com/pwh-pwh/local-ocr/releases
3. Local `cargo build` only if neither is available

Models go to `~/.cache/ocr-rs/models/`.
