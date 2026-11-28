# Runs the headless Godot test suite on Windows.
# Usage:  $env:GODOT = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"; tools\run_tests.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }

function Run-Step($title, $arguments) {
    Write-Host "== $title"
    & $godot @arguments
    if ($LASTEXITCODE -ne 0) { Write-Error "$title failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }
}

Run-Step "Importing assets" @("--headless", "--path", "game", "--import")
Run-Step "Unit tests" @("--headless", "--path", "game", "--script", "res://tests/run_tests.gd")
Run-Step "Smoke test (main scene)" @("--headless", "--path", "game", "--script", "res://tests/smoke_main.gd")
Run-Step "Smoke test (menus)" @("--headless", "--path", "game", "--script", "res://tests/smoke_menu.gd")
Run-Step "Smoke test (LAN lockstep)" @("--headless", "--path", "game", "--script", "res://tests/smoke_lan.gd")
Write-Host "== All tests passed"
