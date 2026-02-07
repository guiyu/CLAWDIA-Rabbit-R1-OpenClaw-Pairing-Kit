param(
  [Parameter(Mandatory = $true)]
  [string]$GatewayHost,
  [int]$Port = 443,
  [ValidateSet('wss', 'ws')]
  [string]$Protocol = 'wss',
  [switch]$SkipHardening,
  [switch]$NoPng
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$preflight = Join-Path $root 'r1-openclaw-preflight.ps1'
$qrGen = Join-Path $root 'r1-generate-qr.ps1'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][scriptblock]$Run
  )
  Write-Host "`n== $Title ==" -ForegroundColor Cyan
  & $Run
}

Invoke-Step -Title '1/3 Preflight checks' -Run {
  & $preflight
}

if (-not $SkipHardening) {
  Invoke-Step -Title '2/3 Apply safe hardening defaults' -Run {
    & openclaw config set gateway.auth.mode token
    & openclaw config set gateway.auth.allowTailscale true
    & openclaw config set gateway.trustedProxies '["127.0.0.1","::1"]'
    & openclaw config set tools.elevated.enabled false
    & openclaw config set browser.evaluateEnabled false
    & openclaw security audit --fix
    & openclaw gateway restart
    & openclaw security audit --deep --json
  }
} else {
  Write-Host "`n== 2/3 Hardening skipped (-SkipHardening) ==" -ForegroundColor Yellow
}

Invoke-Step -Title '3/3 Generate Rabbit QR payload' -Run {
  $params = @{
    GatewayHost = $GatewayHost
    Port = $Port
    Protocol = $Protocol
    OutJson = (Join-Path $root 'r1-gateway-payload.json')
    OutPng = (Join-Path $root 'r1-gateway-qr.png')
  }
  if ($NoPng) { $params['NoPng'] = $true }
  & $qrGen @params
}

Write-Host "`nDone. Next step:" -ForegroundColor Green
Write-Host "powershell -ExecutionPolicy Bypass -File $root\r1-node-pair-watch.ps1 -TimeoutMinutes 10"
