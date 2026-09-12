# GI-TCG AI vs AI: Pre-flight readiness check
# Verifies the standalone bridge is up and both AI players are connected
# before launching agents. Prevents agents from racing ahead of the bridge.
#
# Usage:
#   .\.opencode\check-ready.ps1                 # default url http://localhost:3901
#   .\.opencode\check-ready.ps1 -Url http://localhost:3901
#   .\.opencode\check-ready.ps1 -TimeoutSec 60  # override default 120s wait
#   .\.opencode\check-ready.ps1 -Wait           # block until ready (for chaining)
#
# Exit codes:
#   0  both players connected and game running
#   1  timeout or server unreachable
#   2  one/both players connected but game not started yet (UI tab not clicked)

[CmdletBinding()]
param(
  [string]$Url = "http://localhost:3901",
  [int]$TimeoutSec = 120,
  [switch]$Wait
)

$ErrorActionPreference = "Stop"
$baseUrl = $Url.TrimEnd('/')

function Invoke-BridgeJson {
  param([string]$Path)
  try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/mcp/$Path" -Method Get -TimeoutSec 5 -ErrorAction Stop
    return $response
  } catch {
    return $null
  }
}

function Test-PlayerReady {
  param([int]$Who)
  $result = Invoke-BridgeJson -Path "$Who/ping"
  if ($null -eq $result) {
    return @{ ready = $false; gameRunning = $false; reason = "unreachable" }
  }
  if (-not $result.connected) {
    return @{ ready = $false; gameRunning = $false; reason = "bridge not connected (player $Who)" }
  }
  # gameRunning = bridge.connected && snapshot.gamePhase !== "not_started"
  if (-not $result.gameRunning) {
    return @{ ready = $false; gameRunning = $false; reason = "game not started (click 'MCP模式' tab → start)" }
  }
  return @{ ready = $true; gameRunning = $true; reason = "ok" }
}

function Get-OverallStatus {
  $p0 = Test-PlayerReady -Who 0
  $p1 = Test-PlayerReady -Who 1
  # Game is running only if at least one bridge reports it (both report true
  # in practice, but we accept either to tolerate a brief sync race).
  $gameRunning = $p0.gameRunning -or $p1.gameRunning
  $bothConnected = $p0.ready -and $p1.ready
  return @{
    p0 = $p0
    p1 = $p1
    bothConnected = $bothConnected
    gameRunning = $gameRunning
    fullyReady = $bothConnected -and $gameRunning
  }
}

Write-Host ""
Write-Host "GI-TCG Bridge Readiness Check" -ForegroundColor Cyan
Write-Host "  Target: $baseUrl" -ForegroundColor Cyan
Write-Host "  Mode:   $(if ($Wait) { 'wait' } else { 'once' })" -ForegroundColor Cyan
Write-Host ""

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$lastStatus = $null

while ($true) {
  $status = Get-OverallStatus
  $lastStatus = $status

  $p0Tag = if ($status.p0.ready) { "OK" } else { "..." }
  $p1Tag = if ($status.p1.ready) { "OK" } else { "..." }
  $gameTag = if ($status.gameRunning) { "RUNNING" } else { "IDLE" }

  Write-Host "`r  P0: $p0Tag  P1: $p1Tag  Game: $gameTag                    " -NoNewline

  if ($status.fullyReady) {
    Write-Host ""
    Write-Host ""
    Write-Host "Ready! Both AI players connected, game running." -ForegroundColor Green
    Write-Host "  P0: $($status.p0.reason)"
    Write-Host "  P1: $($status.p1.reason)"
    exit 0
  }

  if (-not $Wait) {
    break
  }

  if ((Get-Date) -gt $deadline) {
    Write-Host ""
    Write-Host ""
    Write-Host "Timeout after ${TimeoutSec}s — bridge not fully ready." -ForegroundColor Red
    Write-Host "  P0: $($status.p0.reason)"
    Write-Host "  P1: $($status.p1.reason)"
    if ($status.bothConnected -and -not $status.gameRunning) {
      exit 2
    }
    exit 1
  }

  Start-Sleep -Milliseconds 800
}

Write-Host ""
Write-Host ""
if ($lastStatus.bothConnected -and -not $lastStatus.gameRunning) {
  Write-Host "Bridge connected but game not started." -ForegroundColor Yellow
  Write-Host "  Open http://localhost:3901 in a browser," -ForegroundColor Yellow
  Write-Host "  switch to the 'MCP模式' tab, set both players to AI," -ForegroundColor Yellow
  Write-Host "  and click '开始对局'." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  P0: $($lastStatus.p0.reason)"
  Write-Host "  P1: $($lastStatus.p1.reason)"
  exit 2
}

Write-Host "Not ready." -ForegroundColor Red
Write-Host "  P0: $($lastStatus.p0.reason)"
Write-Host "  P1: $($lastStatus.p1.reason)"
if ($lastStatus.p0.reason -eq "unreachable" -and $lastStatus.p1.reason -eq "unreachable") {
  Write-Host ""
  Write-Host "  Standalone server unreachable at $baseUrl" -ForegroundColor Red
  Write-Host "  Start it:  cd packages/standalone && pnpm dev" -ForegroundColor Red
}
exit 1
