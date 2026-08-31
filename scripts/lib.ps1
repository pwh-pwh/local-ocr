#Requires -Version 5
# sourced by ocr.ps1 / doctor.ps1 / download-models.ps1

function Get-OcrModelsDir {
    if ($env:LOCAL_OCR_MODELS) { return $env:LOCAL_OCR_MODELS }
    return (Join-Path $env:LOCALAPPDATA "ocr-rs\models")
}

function Test-OcrModelFile([string]$path, [string]$name = "") {
    if (-not (Test-Path $path)) { return $false }
    $len = (Get-Item $path).Length
    $label = if ($name) { $name } else { [IO.Path]::GetFileName($path) }
    $label = $label -replace '\.part$', ''
    if ($label -like "*.txt") { return $len -ge 1000 }
    return $len -ge 100000
}

function Install-OcrModels {
    param([Parameter(Mandatory = $true)][string]$Tier)
    switch ($Tier) {
        { $_ -in @("tiny", "small", "medium") } { }
        default { throw "档位: tiny | small | medium" }
    }
    $models = Get-OcrModelsDir
    $base = if ($env:OCR_RS_MODEL_BASE) { $env:OCR_RS_MODEL_BASE } else { "https://raw.githubusercontent.com/zibo-chen/rust-paddle-ocr/next/models" }
    $files = @(
        "PP-OCRv6_${Tier}_det.mnn",
        "PP-OCRv6_${Tier}_rec.mnn",
        "ppocr_keys_v6_${Tier}.txt"
    )
    New-Item -ItemType Directory -Force -Path $models | Out-Null
    $ready = $true
    foreach ($name in $files) {
        if (-not (Test-OcrModelFile (Join-Path $models $name))) { $ready = $false; break }
    }
    if ($ready) { return }

    Write-Host "下载 PP-OCRv6 $Tier → $models"
    foreach ($name in $files) {
        $path = Join-Path $models $name
        if (Test-OcrModelFile $path $name) {
            Write-Host "已存在: $name"
            continue
        }
        Write-Host "获取: $name"
        $tmp = "$path.part"
        try {
            Invoke-WebRequest -Uri "$base/$name" -OutFile $tmp -UseBasicParsing
            if (-not (Test-OcrModelFile $tmp $name)) {
                throw "下载不完整: $name"
            }
            Move-Item -Force $tmp $path
        } catch {
            Remove-Item -Force $tmp -ErrorAction SilentlyContinue
            throw
        }
    }
    Write-Host "完成。"
}
