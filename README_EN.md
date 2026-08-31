# local-ocr

Local Chinese OCR skill powered by [ocr-rs](https://crates.io/crates/ocr-rs) (PaddleOCR PP-OCRv6 + MNN). RapidOCR / Python is no longer used.

Apache License 2.0.

## Setup

Requires rustc, cargo, cmake, and clang for the first engine build.

```bash
cd <skill_dir>
bash scripts/doctor.sh
```

Models live in `~/.cache/ocr-rs/models/` (override with `LOCAL_OCR_MODELS`).

## Usage

```bash
scripts/ocr photo.jpg
scripts/ocr --format json --tier tiny photo.jpg
scripts/ocr --tier medium --robust scan.png
```

Default stdout is one text line per region. JSON includes `ok`, `text`, and `lines`.

Tiers: `tiny` (default, fast), `small`, `medium` (more accurate).
