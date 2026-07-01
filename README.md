# rapidocr Skill

RapidOCR 图片文字识别技能，支持中英文混合识别。

基于 [RapidOCR](https://github.com/RapidAI/RapidOCR)（Apache License 2.0）。本 skill 遵循 Apache License 2.0 协议。

## 目录结构

```
rapidocr/
├── SKILL.md              # 技能定义文件（Agent 自动加载）
├── README.md             # 本文档
├── pyproject.toml        # uv 依赖声明
├── .python-version       # Python 版本 (3.13)
├── uv.lock               # 依赖锁定
├── .gitignore
├── scripts/
│   ├── ocr_rapid.py      # 主识别脚本（入口）
│   ├── ocr_server.py     # 常驻 HTTP 服务 (端口 9898)
│   └── ocr_preload.py    # 模型预加载
└── references/
    └── rapidocr-api.md   # RapidOCR API 参考
```

## 使用方法

### 直接识别

```bash
cd <skill_dir> && uv run python scripts/ocr_rapid.py <image_path>
```

首次运行会自动启动常驻服务（加载模型约 6 秒），后续识别约 3 秒。

### 手动启动常驻服务

```bash
cd <skill_dir> && uv run python scripts/ocr_server.py &
```

服务监听 `127.0.0.1:9898`，POST `/ocr` 接收 JSON `{"image_path": "..."}`。

## 优化配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `use_cls` | False | 禁用方向分类，减少模型加载 |
| `max_side_len` | 640 | 缩小图片输入，约 40% 提速 |
| `det_use_cuda` | False | CPU 推理 |

## 依赖

- rapidocr-onnxruntime >= 1.4.4
- onnxruntime >= 1.27.0
- opencv-python >= 4.13.0
- numpy >= 2.5.0
- pillow >= 12.2.0
- PyYAML >= 6.0.3
