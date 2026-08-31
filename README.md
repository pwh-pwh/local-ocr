# local-ocr

本地中文 OCR 技能。[ocr-rs](https://crates.io/crates/ocr-rs)（PaddleOCR PP-OCRv6 + MNN）。

**安装后即可用，不必先装 Rust。** Apache License 2.0。

## 安装

把本目录放到 Agent 的 skills 路径下（例如 `~/.hermes/skills/local-ocr`），然后：

**Linux / macOS**

```bash
bash scripts/doctor.sh
scripts/ocr photo.jpg
```

**Windows**（PowerShell，不必装 Git Bash / Rust）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1
powershell -ExecutionPolicy Bypass -File scripts\ocr.ps1 photo.jpg
```

也可双击或在 cmd 里跑 `scripts\ocr.cmd`。第一次调用识别入口会自动 doctor。

准备顺序：

1. 仓库内 `prebuilt/<target>/`（Linux x64/ARM、macOS Apple Silicon、Windows x64）
2. 若本机 target 没有预编译包，再从 GitHub Release 下载
3. 都没有才本机 `cargo build`

模型目录：Linux/macOS 为 `~/.cache/ocr-rs/models/`，Windows 为 `%LOCALAPPDATA%\ocr-rs\models`（可用 `LOCAL_OCR_MODELS` 改）。

## 使用

```bash
scripts/ocr photo.jpg
scripts/ocr --format json --tier tiny photo.jpg
scripts/ocr --tier medium --robust scan.png
```

默认每行一条文本。JSON 含 `ok`、`text`、`lines`。

档位：`tiny`（默认）/ `small` / `medium`。入口会按 `--tier` 自动下载缺失模型。

## 环境变量

| 变量 | 作用 |
|---|---|
| `LOCAL_OCR_BIN` | 自定义引擎二进制 |
| `LOCAL_OCR_MODELS` | 模型目录 |
| `LOCAL_OCR_RELEASE_REPO` | Release 仓库，默认 `pwh-pwh/local-ocr` |
| `OCR_RS_MODEL_BASE` | 模型下载 URL 前缀 |

## 结构

```
local-ocr/
├── SKILL.md
├── scripts/ocr
├── scripts/ocr.ps1
├── scripts/doctor.sh
├── scripts/download-models.sh
├── prebuilt/                 # 预编译引擎（按 target）
└── engine/                   # 源码（仅在没有预编译包时才编译）
```
