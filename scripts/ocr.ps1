#Requires -Version 5
$ErrorActionPreference = "Stop"
$SkillDir = Split-Path -Parent $PSScriptRoot
$Format = "text"
$Tier = "tiny"
$Robust = $false
$Image = $null
$Models = if ($env:LOCAL_OCR_MODELS) { $env:LOCAL_OCR_MODELS } else { Join-Path $env:LOCALAPPDATA "ocr-rs\models" }

function Show-Usage {
    Write-Error "用法: ocr.ps1 [--tier tiny|small|medium] [--robust] [--format text|json] <image_or_url>"
    exit 2
}

function Write-JsonErr($error, $hint) {
    if ($Format -eq "json") {
        $d = @{ ok = $false; error = $error }
        if ($hint) { $d.hint = $hint }
        $d | ConvertTo-Json -Compress
    } else {
        if ($hint) { Write-Error "error: $error ($hint)" } else { Write-Error "error: $error" }
    }
    exit 1
}

function Find-Engine {
    if ($env:LOCAL_OCR_BIN -and (Test-Path $env:LOCAL_OCR_BIN)) { return $env:LOCAL_OCR_BIN }
    $cands = @(
        (Join-Path $SkillDir "bin\local-ocr-engine.exe"),
        (Join-Path $SkillDir "engine\target\release\local-ocr-engine.exe")
    )
    foreach ($c in $cands) { if (Test-Path $c) { return $c } }
    return $null
}

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        "--tier" { $Tier = $args[$i + 1]; $i += 2 }
        "--robust" { $Robust = $true; $i += 1 }
        "--format" { $Format = $args[$i + 1]; $i += 2 }
        "-f" { $Format = $args[$i + 1]; $i += 2 }
        default {
            if ($args[$i] -like "-*") { Show-Usage }
            $Image = $args[$i]; $i += 1
        }
    }
}
if (-not $Image) { Show-Usage }

$Engine = Find-Engine
if (-not $Engine) {
    Write-Host "local-ocr: 首次使用，正在准备引擎和模型（无需 Rust）..." -ForegroundColor DarkGray
    & (Join-Path $PSScriptRoot "doctor.ps1")
    if ($LASTEXITCODE -ne 0) { Write-JsonErr "engine_missing" "powershell -File scripts/doctor.ps1" }
    $Engine = Find-Engine
}
if (-not $Engine) { Write-JsonErr "engine_missing" "powershell -File scripts/doctor.ps1" }

$work = Join-Path $env:TEMP ("local-ocr-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $inputPath = $Image
    if ($Image -match '^https?://') {
        $inputPath = Join-Path $work "input"
        try { Invoke-WebRequest -Uri $Image -OutFile $inputPath -UseBasicParsing } catch { Write-JsonErr "download_failed" $null }
    } elseif (-not (Test-Path $Image)) {
        Write-JsonErr "image_not_found" $Image
    }

    $argList = @($inputPath, "--tier", $Tier, "--format", "json", "--models-dir", $Models)
    if ($Robust) { $argList += "--robust" }
    $raw = & $Engine @argList 2>$null
    $text = if ($raw -is [array]) { $raw -join "`n" } else { [string]$raw }
    $start = $text.IndexOf("{")
    if ($start -lt 0) { Write-JsonErr "infer_failed" $null }
    $obj = $text.Substring($start) | ConvertFrom-Json
    if (-not $obj.ok) { Write-JsonErr $obj.error $obj.hint }
    if ($Format -eq "json") {
        $obj | ConvertTo-Json -Depth 6
    } else {
        if ([string]::IsNullOrWhiteSpace($obj.text)) { "(未识别到文本)" } else { $obj.text }
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
