#Requires -Version 5
param(
    [string]$Tier = "tiny"
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib.ps1")
try {
    Install-OcrModels -Tier $Tier
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
