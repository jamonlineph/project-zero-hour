# Exports hand-made art_source/<category>/<id>.blend files to game assets on Windows (P2-15).
# Usage:  $env:BLENDER = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"; tools\export_blend.ps1 --only us_mbt
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$blender = if ($env:BLENDER) { $env:BLENDER } else { "blender" }
& $blender -b --factory-startup -P blender/export_blend.py -- @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Next: run tools\run_tests.ps1 (it re-imports the new files into Godot)."
