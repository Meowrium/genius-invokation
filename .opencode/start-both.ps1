# GI-TCG AI vs AI: one-click launch both players (Agent mode)
# Usage: .\.opencode\start-both.ps1
#
# Preflight: blocks until the standalone bridge reports both AI players
# connected and the game running. Prevents agents from racing ahead of
# the bridge and timing out on their first wait_for_my_turn.
#
# Prerequisites:
#   1. Standalone server running:  cd packages/standalone && pnpm dev
#   2. Browser open at http://localhost:3901 → 'MCP模式' tab
#      → both players set to AI → '开始对局' clicked

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectDir = Split-Path $ScriptDir -Parent
$P0Script = Join-Path $ScriptDir "start-p0.ps1"
$P1Script = Join-Path $ScriptDir "start-p1.ps1"
$CheckScript = Join-Path $ScriptDir "check-ready.ps1"

Write-Host "GI-TCG AI vs AI (Agent Mode) — preflight check..." -ForegroundColor Cyan

# Preflight: wait for bridge readiness (up to 180s for manual UI interaction)
& $CheckScript -Wait -TimeoutSec 180
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "Preflight failed (exit $LASTEXITCODE). Aborting agent launch." -ForegroundColor Red
  Write-Host "Ensure the standalone server is running and the game is started in MCP mode." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Launching both agents..." -ForegroundColor Green

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue

if ($wt) {
    Write-Host "Using Windows Terminal (split pane)..." -ForegroundColor Green
    
    $wtArgs = @(
        "-w", "0",
        "nt", "--title", "P0 先手", "-d", $ProjectDir,
        "powershell", "-NoExit", "-File", $P0Script,
        ";",
        "sp", "-H", "--title", "P1 后手", "-d", $ProjectDir,
        "powershell", "-NoExit", "-File", $P1Script
    )
    & wt.exe @wtArgs
}
else {
    Write-Host "Windows Terminal not found, using separate PowerShell windows..." -ForegroundColor Yellow
    
    Start-Process powershell -ArgumentList "-NoExit", "-File", $P0Script -WorkingDirectory $ProjectDir
    Start-Sleep -Seconds 2
    Start-Process powershell -ArgumentList "-NoExit", "-File", $P1Script -WorkingDirectory $ProjectDir
}

Write-Host ""
Write-Host "Both agents launched (MCP tools only)!" -ForegroundColor Green
