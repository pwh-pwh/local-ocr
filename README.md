# local-ocr

本地中文 OCR 技能。引擎是 [ocr-rs](https://crates.io/crates/ocr-rs)（PaddleOCR PP-OCRv6 + MNN），不再使用 RapidOCR / Python。

Apache License 2.0。

## 结构

```
local-ocr/
├── SKILL.md
├── scripts/ocr                 # Agent 入口
├── scripts/doctor.sh           # 编译引擎 + 下载 tiny 模型
├── scripts/download-models.sh
└── engine/                     # Rust 引擎（ocr-rs）
```

模型默认在 `~/.cache/ocr-rs/models/`，不进 git。可用 `LOCAL_OCR_MODELS` 改路径。

## 准备

需要 rustc、cargo、cmake、clang（仅首次编译引擎）。

```bash
cd <skill_dir>
bash scripts/doctor.sh
```

## 使用

```bash
scripts/ocr photo.jpg
scripts/ocr --format json --tier tiny photo.jpg
scripts/ocr --tier medium --robust scan.png
```

默认输出纯文本，每行一条。JSON 含 `ok`、`text`、`lines`。

档位：`tiny`（默认，快）/ `small` / `medium`（准）。medium 模型：

```bash
bash scripts/download-models.sh medium
```

## 环境变量

| 变量 | 作用 |
|---|---|
| `LOCAL_OCR_BIN` | 自定义引擎二进制 |
| `LOCAL_OCR_MODELS` | 模型目录 |
| `OCR_RS_MODEL_BASE` | 模型下载 URL 前缀 |
