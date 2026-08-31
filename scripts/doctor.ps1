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
. (Join-Path $PSScriptRoot "lib.ps1")
$Models = Get-OcrModelsDir

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

Install-Engine
Write-Host "检查 tiny 模型..."
Install-OcrModels -Tier "tiny"
Write-Host "OK  入口: $(Join-Path $SkillDir 'scripts\ocr.ps1')"
Write-Host "    引擎: $Dest"
Write-Host "    模型: $Models"
Write-Host "无需长期安装 Rust。"
