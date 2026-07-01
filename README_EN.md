# rapidocr Skill

OCR image text recognition skill powered by RapidOCR, supporting Chinese and English mixed text.

Based on [RapidOCR](https://github.com/RapidAI/RapidOCR) (Apache License 2.0). This skill follows the Apache License 2.0.

## Directory Structure

```
rapidocr/
├── SKILL.md              # Skill definition (auto-loaded by Agent)
├── README.md             # Chinese documentation
├── README_EN.md          # English documentation (this file)
├── pyproject.toml        # uv dependency declaration
├── .python-version       # Python version (3.13)
├── uv.lock               # Dependency lock
├── .gitignore
├── scripts/
│   ├── ocr_rapid.py      # Main recognition script (entry point)
│   ├── ocr_server.py     # Persistent HTTP service (port 9898)
│   └── ocr_preload.py    # Model preloading
└── references/
    └── rapidocr-api.md   # RapidOCR API reference
```

## Usage

### Direct Recognition

```bash
cd <skill_dir> && uv run python scripts/ocr_rapid.py <image_path>
```

The first run auto-starts the persistent service (model loading takes ~6s), subsequent recognitions take ~3s.

### Manual Service Start

```bash
cd <skill_dir> && uv run python scripts/ocr_server.py &
```

The service listens on `127.0.0.1:9898`, accepting POST `/ocr` with JSON `{"image_path": "..."}`.

## Optimization

| Parameter | Value | Description |
|-----------|-------|-------------|
| `use_cls` | False | Disable direction classification, reduce model loading |
| `max_side_len` | 640 | Downscale image input, ~40% speedup |
| `det_use_cuda` | False | CPU inference |

## Dependencies

- rapidocr-onnxruntime >= 1.4.4
- onnxruntime >= 1.27.0
- opencv-python >= 4.13.0
- numpy >= 2.5.0
- pillow >= 12.2.0
- PyYAML >= 6.0.3

## License

Apache License 2.0 — inherited from [RapidOCR](https://github.com/RapidAI/RapidOCR).
