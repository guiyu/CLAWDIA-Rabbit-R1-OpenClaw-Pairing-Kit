param(
  [Parameter(Mandatory = $true)]
  [string]$GatewayHost,
  [int]$Port = 443,
  [ValidateSet('wss', 'ws')]
  [string]$Protocol = 'wss',
  [string]$OutJson = '.\community\r1-openclaw-kit\r1-gateway-payload.json',
  [string]$OutPng = '.\community\r1-openclaw-kit\r1-gateway-qr.png',
  [switch]$NoPng
)

$ErrorActionPreference = 'Continue'

function Get-GatewayToken {
  $raw = & openclaw gateway call settings --json 2>$null
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
      $settings = $raw | ConvertFrom-Json
      if ($settings.gateway.auth.token) {
        return [string]$settings.gateway.auth.token
      }
    } catch {
    }
  }

  $cfgPath = Join-Path $HOME '.openclaw\openclaw.json'
  if (-not (Test-Path -LiteralPath $cfgPath)) {
    throw "Could not find gateway token. Missing $cfgPath"
  }
  $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
  if (-not $cfg.gateway.auth.token) {
    throw 'Could not find gateway.auth.token in openclaw.json'
  }
  return [string]$cfg.gateway.auth.token
}

$token = Get-GatewayToken

$payload = [ordered]@{
  type = 'clawdbot-gateway'
  version = 1
  ips = @($GatewayHost)
  port = $Port
  token = $token
  protocol = $Protocol
}

$json = $payload | ConvertTo-Json -Depth 6

$jsonDir = Split-Path -Path $OutJson -Parent
if ($jsonDir) {
  New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
}
$pngDir = Split-Path -Path $OutPng -Parent
if ($pngDir) {
  New-Item -ItemType Directory -Path $pngDir -Force | Out-Null
}

$json | Out-File -FilePath $OutJson -Encoding utf8

if (-not $NoPng) {
  Add-Type -AssemblyName System.Web
  $encoded = [System.Web.HttpUtility]::UrlEncode($json)
  $url = "https://quickchart.io/qr?size=900&text=$encoded"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $OutPng
}

Write-Host "Payload JSON: $OutJson"
if (-not $NoPng) {
  Write-Host "QR PNG: $OutPng"
}
Write-Host 'Done. Keep token private when sharing files/screenshots.'
