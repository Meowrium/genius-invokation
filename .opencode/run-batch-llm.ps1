# GI-TCG Batch LLM Orchestrator Launcher
# Usage: .\.opencode\run-batch-llm.ps1 [-Config <path>] [-Concurrency N] [-ModelP0 <model>] [-ModelP1 <model>]
#
# v2 features: per-side config (model/apiBase/apiKey/prompt/sandbox) in batch-llm-v2.json
# Sandbox: enable with -SandboxEnabled 1
#
# Reads API credentials from environment variables or prompts for them.
#
# Environment variables:
#   $env:OPENAI_API_BASE  - API base URL (e.g. https://api.edgefn.net/v1)
#   $env:OPENAI_API_KEY   - API key
#
# Or pass directly:
#   .\.opencode\run-batch-llm.ps1 -ApiBase "https://..." -ApiKey "sk-..."

param(
  [string]$Config = ".opencode/batch-llm-v2.json",
  [int]$Concurrency = 4,
  [string]$ModelP0 = "deepseek-v4-flash",
  [string]$ModelP1 = "deepseek-v4-flash",
  [string]$ApiBase = "",
  [string]$ApiKey = "",
  [string]$OutputDir = ".opencode/tmp/batch-results",
  [int]$BasePort = 3901,
  [ValidateSet("direct-action", "fragmented-decision")]
  [string]$ToolExposureMode = "direct-action",
  [int]$StartOffset = 0,
  [int]$GameCount = 0,
  [int]$SandboxEnabled = 0,
  [string]$SandboxPromptTemplate = ".opencode/prompts/sandbox-analysis-gen.md",
  [string]$SandboxModel = "",
  [double]$SandboxTemperature = 0.4,
  [int]$SandboxMaxTokens = 8192
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectDir = Split-Path $ScriptDir -Parent

# Resolve credentials
if (-not $ApiBase) { $ApiBase = $env:OPENAI_API_BASE }
if (-not $ApiKey)  { $ApiKey = $env:OPENAI_API_KEY }

if (-not $ApiBase -or -not $ApiKey) {
  Write-Host "Error: API base and key are required." -ForegroundColor Red
  Write-Host "Set environment variables:" -ForegroundColor Yellow
  Write-Host '  $env:OPENAI_API_BASE = "https://api.example.com/v1"' -ForegroundColor Yellow
  Write-Host '  $env:OPENAI_API_KEY  = "sk-xxx"' -ForegroundColor Yellow
  Write-Host "Or pass as parameters:" -ForegroundColor Yellow
  Write-Host '  .\run-batch-llm.ps1 -ApiBase "https://..." -ApiKey "sk-..."' -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "=== GI-TCG Batch LLM Orchestrator ===" -ForegroundColor Cyan
Write-Host "  Config:      $Config" -ForegroundColor Cyan
Write-Host "  Model P0:    $ModelP0" -ForegroundColor Cyan
Write-Host "  Model P1:    $ModelP1" -ForegroundColor Cyan
Write-Host "  Concurrency: $Concurrency" -ForegroundColor Cyan
Write-Host "  Output:      $OutputDir" -ForegroundColor Cyan
Write-Host "  Base Port:   $BasePort" -ForegroundColor Cyan
Write-Host "  Mode:        $ToolExposureMode" -ForegroundColor Cyan
Write-Host "  Sandbox:     $(if ($SandboxEnabled) { "enabled" } else { "disabled" })" -ForegroundColor Cyan
if ($StartOffset -gt 0) { Write-Host "  StartOffset: $StartOffset" -ForegroundColor Cyan }
if ($GameCount -gt 0) { Write-Host "  GameCount:   $GameCount" -ForegroundColor Cyan }
Write-Host ""

# Ensure output directory exists
$null = New-Item -ItemType Directory -Path "$ProjectDir\$OutputDir" -Force -ErrorAction SilentlyContinue

$orchestratorArgs = @(
  "exec", "gnx",
  "packages/mcp/src/headless/run-batch-llm.ts",
  "--config", $Config,
  "--api-base", $ApiBase,
  "--api-key", $ApiKey,
  "--model-p0", $ModelP0,
  "--model-p1", $ModelP1,
  "--system-prompt-p0", "$ProjectDir\.opencode\prompts\p0-start.md",
  "--system-prompt-p1", "$ProjectDir\.opencode\prompts\p1-start.md",
  "--concurrency", $Concurrency,
  "--output-dir", $OutputDir,
  "--base-port", $BasePort,
  "--tool-exposure-mode", $ToolExposureMode,
  "--sandbox-enabled", $SandboxEnabled,
  "--sandbox-prompt-template", $SandboxPromptTemplate,
  "--sandbox-temperature", $SandboxTemperature,
  "--sandbox-max-tokens", $SandboxMaxTokens
)

if ($SandboxModel) {
  $orchestratorArgs += @("--sandbox-model", $SandboxModel)
}

if ($StartOffset -gt 0) {
  $orchestratorArgs += @("--start-offset", $StartOffset)
}
if ($GameCount -gt 0) {
  $orchestratorArgs += @("--game-count", $GameCount)
}

Write-Host "Starting orchestrator..." -ForegroundColor Green
Set-Location $ProjectDir
& pnpm @orchestratorArgs
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
  Write-Host "`nOrchestrator exited with code $exitCode" -ForegroundColor Red
} else {
  Write-Host "`nBatch complete!" -ForegroundColor Green
}

exit $exitCode
