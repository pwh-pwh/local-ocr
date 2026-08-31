---
name: local-ocr
description: 本地中文 OCR（ocr-rs / PP-OCRv6）。识别本地图片、截图、证件、票据、扫描件中的文字。用户提到 OCR、识别图片、提取文字、识别截图时使用。飞书消息里的图先下载到本地再调用本技能。不要用 Python PaddleOCR 或 RapidOCR。
version: 4.1.1
metadata:
  requires:
    bins: ["curl", "python3"]
---

# local-ocr

本机 PP-OCRv6（ocr-rs + MNN）。默认 tiny。用户**不用装 Rust**。

## 入口

定位本 skill 目录（例如 `~/.hermes/skills/local-ocr`），然后：

```bash
"<skill_dir>/scripts/ocr" [--tier tiny|small|medium] [--robust] [--format text|json] <image_or_url>
```

- 第一次调用会自动准备引擎和 tiny 模型（Linux / macOS Apple Silicon / Windows x64 用仓库 `prebuilt/`）
- Linux/macOS：`bash "<skill_dir>/scripts/doctor.sh"`
- Windows：`powershell -File "<skill_dir>/scripts/doctor.ps1"`（或 `scripts\doctor.cmd`）
- 默认 `--format text`：stdout 每行一条识别文本，不要再加说明
- `--format json`：`ok`、`text`、`lines`、`infer_ms`
- 图片可以是本地路径或 http(s) URL
- 混排竖排加 `--robust`
- 要更高精度用 `--tier medium`

## 失败

| error | 处理 |
|---|---|
| `engine_missing` / `model_missing` | Unix：`bash scripts/doctor.sh`；Windows：`scripts\doctor.cmd` |
| `image_not_found` | 向用户要有效路径 |
| `download_failed` | URL 不可达 |
| `infer_failed` | 换图或 `--tier medium` |

不要改去调 Python OCR。
