$ErrorActionPreference = 'SilentlyContinue'

param(
  [string]$ConfigPath = "$HOME\.openclaw\openclaw.json"
)

$fail = 0

function Pass($msg) { Write-Host "[PASS] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Fail($msg) {
  Write-Host "[FAIL] $msg" -ForegroundColor Red
  $script:fail++
}

Write-Host '== OpenClaw + R1 Preflight ==' -ForegroundColor Cyan

$oc = Get-Command openclaw -ErrorAction SilentlyContinue
if ($oc) { Pass "openclaw found at $($oc.Source)" } else { Fail 'openclaw CLI not found in PATH' }

$ts = Get-Command tailscale -ErrorAction SilentlyContinue
if ($ts) { Pass "tailscale found at $($ts.Source)" } else { Warn 'tailscale CLI not found in PATH' }

$health = & openclaw gateway health 2>&1
if ($LASTEXITCODE -eq 0) { Pass 'gateway health is OK' } else { Fail "gateway health failed: $health" }

$statusRaw = & openclaw gateway call status --json 2>$null
if ([string]::IsNullOrWhiteSpace($statusRaw)) {
  Fail 'gateway status RPC returned no JSON'
} else {
  try {
    $null = $statusRaw | ConvertFrom-Json
    Pass 'gateway status RPC returned valid JSON'
  } catch {
    Fail 'gateway status RPC returned invalid JSON'
  }
}

if ($ts) {
  $tsStatus = & tailscale status 2>&1
  if ($LASTEXITCODE -eq 0) { Pass 'tailscale status OK' } else { Warn "tailscale status failed: $tsStatus" }

  $serve = & tailscale serve status 2>&1
  if ($LASTEXITCODE -eq 0) {
    if ($serve -match '127\.0\.0\.1') {
      Pass 'tailscale serve has local forwarding rule(s)'
    } else {
      Warn 'tailscale serve status returned, but no explicit localhost mapping detected'
    }
  } else {
    Warn "tailscale serve status failed: $serve"
  }
}

if (Test-Path -LiteralPath $ConfigPath) {
  try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    if ($cfg.gateway.auth.mode -eq 'token') { Pass 'gateway.auth.mode is token' } else { Warn "gateway.auth.mode is '$($cfg.gateway.auth.mode)' (recommended: token)" }
    if ($cfg.gateway.auth.allowTailscale -eq $true) { Pass 'gateway.auth.allowTailscale is true' } else { Warn 'gateway.auth.allowTailscale is not true' }

    $proxies = @($cfg.gateway.trustedProxies)
    if ($proxies -contains '127.0.0.1' -and $proxies -contains '::1') {
      Pass 'gateway.trustedProxies includes loopback IPv4 and IPv6'
    } else {
      Warn 'gateway.trustedProxies missing 127.0.0.1 and/or ::1'
    }

    if ($cfg.tools.elevated.enabled -eq $false) { Pass 'tools.elevated.enabled is false' } else { Warn 'tools.elevated.enabled is not false' }
    if ($cfg.browser.evaluateEnabled -eq $false) { Pass 'browser.evaluateEnabled is false' } else { Warn 'browser.evaluateEnabled is not false' }
  } catch {
    Fail "could not parse config JSON at $ConfigPath"
  }
} else {
  Warn "config not found at $ConfigPath"
}

Write-Host ''
if ($fail -eq 0) {
  Write-Host 'Preflight complete: no blocking failures.' -ForegroundColor Green
  exit 0
}

Write-Host "Preflight complete: $fail blocking failure(s)." -ForegroundColor Red
exit 1
