# Publish a new Web build to GitHub Pages in one go:
#   1. export the "Web" preset headless into build/web
#   2. patch the service worker to network-first
#   3. re-zip build/web for itch.io (build/magic-war-web.zip)
#   4. commit everything (source + build/web) and push - GitHub Actions
#      then deploys build/web to Pages.
#
# Usage (from the project folder):
#   powershell -ExecutionPolicy Bypass -File tools\publish.ps1 "What changed"
# Finds Godot on any of our PCs automatically (see $candidates below);
# set $env:GODOT to override. Needs Godot's Web export templates installed
# (Editor > Manage Export Templates) on the PC it runs on.

param([string]$Message = "")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

# Godot console exe: $env:GODOT if set, otherwise the first of these that
# exists on this PC. Add a line here for any new machine.
$candidates = @(
    "D:\Godot\Godot_v4.7-stable_win64_console.exe",                         # Desktop (Alon)
    "C:\Users\akore\OneDrive\Godot\Godot_v4.7-stable_win64_console.exe"     # Other PC (akore)
)
# Third PC: Godot lives in C:\Godot. Any version's console exe there counts,
# newest first, so updating Godot doesn't break this script.
$candidates += @(Get-ChildItem "C:\Godot\Godot_v*_win64_console.exe" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | ForEach-Object { $_.FullName })
$godot = $env:GODOT
if (-not $godot) { $godot = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if (-not $godot -or -not (Test-Path $godot)) {
    throw "Godot not found. Checked: $($candidates -join ', '). Set `$env:GODOT to your Godot console exe."
}
Write-Host "== Using Godot: $godot"
if (-not $Message) { $Message = "Web build " + (Get-Date -Format "yyyy-MM-dd HH:mm") }

Write-Host "== Exporting Web build..."
New-Item -ItemType Directory -Force build\web | Out-Null
& $godot --headless --export-release "Web" build/web/index.html | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path build\web\index.html)) {
    throw "Godot export failed (exit $LASTEXITCODE). Try exporting from the editor to see the error."
}

Write-Host "== Patching service worker..."
# Needs Python. Windows has a fake "python" that only opens the Microsoft
# Store, so try each name and keep the first that really runs.
$python = $null
foreach ($name in @("py", "python", "python3")) {
    try {
        & $name --version *> $null
        if ($LASTEXITCODE -eq 0) { $python = $name; break }
    } catch {}
}
if ($python) {
    & $python tools/patch_service_worker.py build/web
    if ($LASTEXITCODE -ne 0) { throw "Service worker patch failed." }
} else {
    # The GitHub Pages deploy runs the same patch, so the live site is fine.
    # Only the itch.io zip keeps Godot's original (cache-first) worker.
    Write-Warning "Python not found: skipping the local service worker patch. GitHub Pages still gets it; the itch.io zip won't. Install Python to patch it here too."
}

Write-Host "== Zipping for itch.io..."
Compress-Archive -Path build\web\* -DestinationPath build\magic-war-web.zip -Force

Write-Host "== Committing and pushing..."
# git prints normal progress ("To https://github.com/...") on stderr, which
# Windows PowerShell turns into an error under "Stop" even when git
# succeeded. So from here, judge git by its exit code only.
$ErrorActionPreference = "Continue"
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "Nothing changed since the last publish - nothing to push."
    exit 0
}
git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
git push
if ($LASTEXITCODE -ne 0) { throw "git push failed." }

Write-Host ""
Write-Host "Pushed. GitHub is deploying it now (about 1 minute):"
Write-Host "  https://github.com/basementgames42-hash/magic-war/actions"
Write-Host "Live at: https://basementgames42-hash.github.io/magic-war/"
