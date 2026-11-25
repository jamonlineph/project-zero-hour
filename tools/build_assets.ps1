# Generates placeholder models and renders icons/sprites with Blender on Windows.
# Usage:  $env:BLENDER = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"; tools\build_assets.ps1 --sheets
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$blender = if ($env:BLENDER) { $env:BLENDER } else { "blender" }
& $blender -b --factory-startup -P blender/build_assets.py -- @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Next: run tools\run_tests.ps1 (it re-imports the new files into Godot)."
