<#
.SYNOPSIS
  Builds a Power Automate legacy import package (.zip) from the package/ folder.

.DESCRIPTION
  Zips the *contents* of package/ (not the package folder itself) so the zip root
  contains manifest.json and Microsoft.Flow/ — required for Import Package (Legacy).

.EXAMPLE
  .\build-package.ps1
#>

[CmdletBinding()]
param(
    [string]$PackageDir = "",
    [string]$OutDir = "",
    [string]$ZipName = "KV-Secret-Expiry-Alert.zip"
)

$ErrorActionPreference = "Stop"

# Resolve repo root even when $PSScriptRoot is empty (some hosts)
$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($PackageDir)) {
    $PackageDir = Join-Path $scriptRoot "package"
}
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $scriptRoot "dist"
}

if (-not (Test-Path -LiteralPath $PackageDir)) {
    throw "Package directory not found: $PackageDir"
}

$manifest = Join-Path $PackageDir "manifest.json"
if (-not (Test-Path -LiteralPath $manifest)) {
    throw "manifest.json missing at package root: $manifest"
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$zipPath = Join-Path $OutDir $ZipName
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

# Compress package contents so zip root = manifest.json + Microsoft.Flow/
$items = Get-ChildItem -LiteralPath $PackageDir -Force
if (-not $items) {
    throw "Package directory is empty: $PackageDir"
}

Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

# Quick integrity check: ensure expected entries exist
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $names = $zip.Entries | ForEach-Object { $_.FullName.Replace("\", "/") }
    $required = @(
        "manifest.json",
        "Microsoft.Flow/flows/manifest.json",
        "Microsoft.Flow/flows/a1b2c3d4-e5f6-7890-abcd-ef1234567890/definition.json",
        "Microsoft.Flow/flows/a1b2c3d4-e5f6-7890-abcd-ef1234567890/apisMap.json",
        "Microsoft.Flow/flows/a1b2c3d4-e5f6-7890-abcd-ef1234567890/connectionsMap.json"
    )
    foreach ($r in $required) {
        if ($names -notcontains $r) {
            throw "Zip is missing required entry: $r`nFound:`n$($names -join "`n")"
        }
    }
}
finally {
    $zip.Dispose()
}

$sizeKb = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host "Built: $zipPath ($sizeKb KB)"
Write-Host "Import via: make.powerautomate.com > My flows > Import > Import Package (Legacy)"
