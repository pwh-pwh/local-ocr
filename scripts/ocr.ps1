#Requires -Version 5
$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"
$Utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $Utf8
[Console]::InputEncoding = $Utf8
$OutputEncoding = $Utf8

$SkillDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "lib.ps1")
$Format = "text"
$Tier = "tiny"
$Robust = $false
$Image = $null
$Models = Get-OcrModelsDir

function Write-Utf8([string]$s) {
    $bytes = $Utf8.GetBytes($s)
    $out = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    if (-not $s.EndsWith("`n")) {
        $nl = $Utf8.GetBytes([Environment]::NewLine)
        $out.Write($nl, 0, $nl.Length)
    }
}

function Show-Usage {
    [Console]::Error.WriteLine("用法: ocr.ps1 [--tier tiny|small|medium] [--robust] [--format text|json] <image_or_url>")
    exit 2
}

function Write-JsonErr($error, $hint) {
    if ($Format -eq "json") {
        $d = @{ ok = $false; error = $error }
        if ($hint) { $d.hint = $hint }
        Write-Utf8 (($d | ConvertTo-Json -Compress))
    } else {
        if ($hint) { [Console]::Error.WriteLine("error: $error ($hint)") }
        else { [Console]::Error.WriteLine("error: $error") }
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

function ConvertTo-ArgString([string[]]$parts) {
    ($parts | ForEach-Object {
        if ($_ -notmatch '[ \t"]') { return $_ }
        '"' + (($_ -replace '\\', '\\') -replace '"', '\"') + '"'
    }) -join ' '
}

function Get-FirstJsonObject([string]$raw) {
    $start = $raw.IndexOf("{")
    if ($start -lt 0) { return $null }
    $depth = 0
    $inStr = $false
    $escape = $false
    for ($i = $start; $i -lt $raw.Length; $i++) {
        $c = $raw[$i]
        if ($inStr) {
            if ($escape) { $escape = $false; continue }
            if ($c -eq [char]0x5C) { $escape = $true; continue }
            if ($c -eq [char]'"') { $inStr = $false }
            continue
        }
        switch ($c) {
            '"' { $inStr = $true }
            '{' { $depth++ }
            '}' {
                $depth--
                if ($depth -eq 0) {
                    return $raw.Substring($start, $i - $start + 1)
                }
            }
        }
    }
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
if ($Tier -notin @("tiny", "small", "medium")) {
    Write-JsonErr "invalid_tier" "--tier 只能是 tiny / small / medium"
}

$Engine = Find-Engine
if (-not $Engine) {
    [Console]::Error.WriteLine("local-ocr: 首次使用，正在准备引擎和模型（无需 Rust）...")
    & (Join-Path $PSScriptRoot "doctor.ps1")
    if ($LASTEXITCODE -ne 0) { Write-JsonErr "engine_missing" "powershell -File scripts/doctor.ps1" }
    $Engine = Find-Engine
}
if (-not $Engine) { Write-JsonErr "engine_missing" "powershell -File scripts/doctor.ps1" }

try {
    Install-OcrModels -Tier $Tier
} catch {
    Write-JsonErr "model_missing" $_.Exception.Message
}

$work = $null
try {
    $inputPath = $Image
    if ($Image -match '^https?://') {
        $work = Join-Path $env:TEMP ("local-ocr-" + [guid]::NewGuid().ToString("n"))
        New-Item -ItemType Directory -Path $work | Out-Null
        $inputPath = Join-Path $work "input"
        try { Invoke-WebRequest -Uri $Image -OutFile $inputPath -UseBasicParsing } catch { Write-JsonErr "download_failed" $null }
    } elseif (-not (Test-Path $Image)) {
        Write-JsonErr "image_not_found" $Image
    }

    $argList = @($inputPath, "--tier", $Tier, "--format", "json", "--models-dir", $Models)
    if ($Robust) { $argList += "--robust" }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Engine
    $psi.Arguments = ConvertTo-ArgString $argList
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = $Utf8
    if ($psi.PSObject.Properties.Name -contains "StandardErrorEncoding") {
        $psi.StandardErrorEncoding = $Utf8
    }
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $raw = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($err) { [Console]::Error.Write($err) }

    $jsonText = Get-FirstJsonObject $raw
    if (-not $jsonText) { Write-JsonErr "infer_failed" $err }
    $obj = $jsonText | ConvertFrom-Json
    if (-not $obj.ok -or $proc.ExitCode -ne 0) {
        if ($Format -eq "json") { Write-Utf8 $jsonText }
        else { Write-JsonErr $obj.error $obj.hint }
        exit 1
    }
    if ($Format -eq "json") {
        Write-Utf8 $jsonText
    } else {
        $t = [string]$obj.text
        if ([string]::IsNullOrWhiteSpace($t)) { Write-Utf8 "(未识别到文本)" } else { Write-Utf8 $t }
    }
} finally {
    if ($work) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
}
