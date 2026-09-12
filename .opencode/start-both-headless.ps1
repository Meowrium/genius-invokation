# GI-TCG AI vs AI: Headless launch (no browser needed)
# Usage: .\.opencode\start-both-headless.ps1
#
# Starts a headless game runner (Node process with embedded HTTP bridge)
# then launches both AI agents via start-both.ps1 (which runs preflight
# check + launches opencode agents).
#
# Prerequisites:
#   - pnpm build (core + mcp packages must be built)
#   - .opencode/opencode-p0-agent.json and opencode-p1-agent.json configured
#
# Override defaults:
#   $env:GI_TCG_DECK0 = "<deck_code>"
#   $env:GI_TCG_DECK1 = "<deck_code>"

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectDir = Split-Path $ScriptDir -Parent

$Deck0 = if ($env:GI_TCG_DECK0) { $env:GI_TCG_DECK0 } else {
  "FZDByRUNGRCB0WoNFlGgWpEPE0AB9TAPFGCB9kgWGIERCoEQDLFADcQQDPFgacYWDJAA"
}
$Deck1 = if ($env:GI_TCG_DECK1) { $env:GI_TCG_DECK1 } else {
  "FdHxNj8TAWDQxFkMFkAhyWIYCYDA45wOCUDQ5J0PGEAh9IIPGWDh9p4YC6FgirYRCxAA"
}
$Port = if ($env:GI_TCG_PORT) { $env:GI_TCG_PORT } else { "3901" }

Write-Host ""
Write-Host "GI-TCG AI vs AI (Headless Mode)" -ForegroundColor Cyan
Write-Host "  Deck0: $Deck0" -ForegroundColor Cyan
Write-Host "  Deck1: $Deck1" -ForegroundColor Cyan
Write-Host "  Port:  $Port" -ForegroundColor Cyan
Write-Host ""

# Start headless runner in background
$headlessArgs = @(
  "/c", "pnpm",
  "exec", "gnx",
  "packages/mcp/src/headless/run-headless.ts",
  "--deck0", $Deck0,
  "--deck1", $Deck1,
  "--port", $Port
)

# Ensure log directory exists
$null = New-Item -ItemType Directory -Path "$ProjectDir\.opencode\tmp" -Force -ErrorAction SilentlyContinue

Write-Host "Starting headless game runner..." -ForegroundColor Green
$headlessProc = Start-Process -FilePath "cmd.exe" -ArgumentList $headlessArgs -PassThru -NoNewWindow -WorkingDirectory $ProjectDir -RedirectStandardOutput "$ProjectDir\.opencode\tmp\headless-stdout.log" -RedirectStandardError "$ProjectDir\.opencode\tmp\headless-stderr.log"
if ($LASTEXITCODE -ne 0 -and $headlessProc.HasExited) {
  Write-Host "Headless runner failed to start. Check .opencode/tmp/headless-stderr.log" -ForegroundColor Red
  exit 1
}

# Wait for headless bridge to be ready
Write-Host "Waiting for headless bridge..." -ForegroundColor Yellow
$CheckScript = Join-Path $ScriptDir "check-ready.ps1"
& $CheckScript -Wait -TimeoutSec 30 -Url "http://localhost:$Port"
if ($LASTEXITCODE -ne 0) {
  Write-Host "Headless bridge not ready. Check .opencode/tmp/headless-stderr.log" -ForegroundColor Red
  exit $LASTEXITCODE
}

# Launch both agents (they connect to the headless bridge via HTTP)
$StartBothScript = Join-Path $ScriptDir "start-both.ps1"
& $StartBothScript
