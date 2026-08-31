#Requires -Version 5
$ErrorActionPreference = "Stop"
$SkillDir = Split-Path -Parent $PSScriptRoot
$Repo = if ($env:LOCAL_OCR_RELEASE_REPO) { $env:LOCAL_OCR_RELEASE_REPO } else { "pwh-pwh/local-ocr" }
$Cargo = Join-Path $SkillDir "engine\Cargo.toml"
$Tag = "v" + ([regex]::Match((Get-Content $Cargo -Raw), 'version = "([^"]+)"').Groups[1].Value)
$Target = "x86_64-pc-windows-msvc"
$DestDir = Join-Path $SkillDir "bin"
$Dest = Join-Path $DestDir "local-ocr-engine.exe"
$Asset = "local-ocr-engine-$Target.exe"
$Prebuilt = Join-Path $SkillDir "prebuilt\$Target\local-ocr-engine.exe"
$Force = $args -contains "--force"
$Models = if ($env:LOCAL_OCR_MODELS) { $env:LOCAL_OCR_MODELS } else { Join-Path $env:LOCALAPPDATA "ocr-rs\models" }
$ModelBase = if ($env:OCR_RS_MODEL_BASE) { $env:OCR_RS_MODEL_BASE } else { "https://raw.githubusercontent.com/zibo-chen/rust-paddle-ocr/next/models" }

Write-Host "== local-ocr doctor =="
Write-Host "平台: $Target  版本: $Tag"

function Install-Engine {
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    if ((-not $Force) -and (Test-Path $Dest)) {
        Write-Host "引擎已就绪: $Dest"
        return
    }
    if (Test-Path $Prebuilt) {
        Write-Host "使用仓库预编译包: $Prebuilt"
        Copy-Item -Force $Prebuilt $Dest
        return
    }
    $urls = @(
        "https://github.com/$Repo/releases/download/$Tag/$Asset",
        "https://github.com/$Repo/releases/latest/download/$Asset"
    )
    if ($env:LOCAL_OCR_RELEASE_BASE) {
        $urls = @("$($env:LOCAL_OCR_RELEASE_BASE)/$Asset") + $urls
    }
    foreach ($url in $urls) {
        Write-Host "尝试下载: $url"
        try {
            Invoke-WebRequest -Uri $url -OutFile $Dest -UseBasicParsing
            if (Test-Path $Dest) { Write-Host "已安装 $Dest"; return }
        } catch {
            continue
        }
    }
    throw @"
无法准备 Windows 引擎。请任选其一：
  1. 从 https://github.com/$Repo/releases 下载 $Asset 放到 bin\
  2. 安装 rustc/cargo + cmake + LLVM 后在 engine\ 执行 cargo build --release
  3. 设置 LOCAL_OCR_BIN 指向已有 local-ocr-engine.exe
"@
}

function Install-Models {
    New-Item -ItemType Directory -Force -Path $Models | Out-Null
    Write-Host "检查 tiny 模型... $Models"
    $files = @(
        "PP-OCRv6_tiny_det.mnn",
        "PP-OCRv6_tiny_rec.mnn",
        "ppocr_keys_v6_tiny.txt"
    )
    foreach ($name in $files) {
        $path = Join-Path $Models $name
        if ((Test-Path $path) -and ((Get-Item $path).Length -gt 0)) {
            Write-Host "已存在: $name"
            continue
        }
        Write-Host "获取: $name"
        Invoke-WebRequest -Uri "$ModelBase/$name" -OutFile $path -UseBasicParsing
    }
}

Install-Engine
Install-Models
Write-Host "OK  入口: $(Join-Path $SkillDir 'scripts\ocr.ps1')"
Write-Host "    引擎: $Dest"
Write-Host "    模型: $Models"
Write-Host "无需长期安装 Rust。"
