# local-ocr

本地中文 OCR 技能。[ocr-rs](https://crates.io/crates/ocr-rs)（PaddleOCR PP-OCRv6 + MNN）。

**安装后即可用，不必先装 Rust。** Apache License 2.0。

## 安装

把本目录放到 Agent 的 skills 路径下（例如 `~/.hermes/skills/local-ocr`），然后：

```bash
bash scripts/doctor.sh
```

或直接识别，第一次会自动准备：

```bash
scripts/ocr photo.jpg
```

`doctor.sh` 顺序：

1. 仓库内 `prebuilt/<target>/`（目前带 **Linux x86_64**）
2. GitHub Release：https://github.com/pwh-pwh/rapid-ocr/releases
3. 都没有才尝试本机 `cargo build`（这时才需要 Rust / cmake / clang）

模型下载到 `~/.cache/ocr-rs/models/`（可用 `LOCAL_OCR_MODELS` 改）。

## 使用

```bash
scripts/ocr photo.jpg
scripts/ocr --format json --tier tiny photo.jpg
scripts/ocr --tier medium --robust scan.png
```

默认每行一条文本。JSON 含 `ok`、`text`、`lines`。

档位：`tiny`（默认）/ `small` / `medium`。medium 需额外模型：

```bash
bash scripts/download-models.sh medium
```

## 环境变量

| 变量 | 作用 |
|---|---|
| `LOCAL_OCR_BIN` | 自定义引擎二进制 |
| `LOCAL_OCR_MODELS` | 模型目录 |
| `LOCAL_OCR_RELEASE_REPO` | Release 仓库，默认 `pwh-pwh/rapid-ocr` |
| `OCR_RS_MODEL_BASE` | 模型下载 URL 前缀 |

## 结构

```
local-ocr/
├── SKILL.md
├── scripts/ocr
├── scripts/doctor.sh
├── prebuilt/                 # 预编译引擎（按 target）
└── engine/                   # 源码（仅在没有预编译包时才编译）
```
