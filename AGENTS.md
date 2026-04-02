# CLAWDIA - Agent Guidelines

## Project Overview

PowerShell and Bash utilities for connecting Rabbit R1 to OpenClaw with Tailscale. No build system or test framework present.

## Scripts

**Windows (PowerShell):**
```powershell
# Preflight check
powershell -ExecutionPolicy Bypass -File .\r1-openclaw-preflight.ps1

# Full setup (generate QR)
powershell -ExecutionPolicy Bypass -File .\setup-community-kit.ps1 -GatewayHost "your-host.tailnet.ts.net"

# Pair watcher (keep terminal open during pairing)
powershell -ExecutionPolicy Bypass -File .\r1-node-pair-watch.ps1 -TimeoutMinutes 10

# Direct QR generation
powershell -ExecutionPolicy Bypass -File .\r1-generate-qr.ps1 -GatewayHost "host.ts.net" -Port 443
```

**Linux (Bash):**
```bash
# Preflight check
./r1-openclaw-preflight.sh

# Full setup (generate QR)
./setup-community-kit.sh --GatewayHost "your-host.tailnet.ts.net"

# Pair watcher (keep terminal open during pairing)
./r1-node-pair-watch.sh --TimeoutMinutes 10

# Direct QR generation
./r1-generate-qr.sh --GatewayHost "host.ts.net" --Port 443
```

**One-Click Installation (Linux only):**
```bash
# Download and install all scripts to PATH
./install.sh
```

## Common Options

All scripts support these optional flags:
- `--SkipHardening` / `-SkipHardening`: Skip security hardening step
- `--NoPng` / `-NoPng`: Generate JSON only, skip PNG QR code
- `--Protocol <wss|ws>`: WebSocket protocol (default: 'wss')
- `--Port <number>`: TCP port (default: 443)

## No Tests Present

This is a shell-script project; no unit/integration tests exist. Scripts are validated externally by manual operation.

## Code Style Guidelines

### Error Handling (PowerShell)
- Set `$ErrorActionPreference = 'Stop'` or `'SilentlyContinue'` at file start
- Use `2>$null` to suppress non-critical errors; `2>&1` to capture them
- Always check exit status via `$LASTEXITCODE` after CLI commands
- Wrap external calls in try/catch for JSON parsing

### Error Handling (Bash)
- Use `set -euo pipefail` at file for strict mode
- Capture stderr appropriately: `2>/dev/null` to suppress, `2>&1` to capture
- Check command exit status with `$?` or conditional checks
- Parse JSON with `jq`; handle failures gracefully

### Function Conventions
- Use `Pass`, `Warn`, `Fail` helper functions for status messages
- Prefix colors: Green=`Pass`, Yellow=`Warn`, Red=`Fail`, Cyan=`Headers`
- Functions follow `Verb-Noun` pattern (e.g., `Invoke-Step`)

### Param Blocks (PowerShell)
```powershell
param(
  [Parameter(Mandatory = $true)]
  [string]$RequiredArg,
  [int]$OptionalArg = 42,
  [ValidateSet('a', 'b')]
  [string]$Choice = 'a',
  [switch]$Flag
)
```

### Variable Declaration (Bash)
```bash
#!/bin/bash
set -euo pipefail

GATEWAY_HOST=""
PORT=443
PROTOCOL="wss"
SKIP_HARDENING=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --GatewayHost) GATEWAY_HOST="$2"; shift 2 ;;
        --Port) PORT="$2"; shift 2 ;;
        --Protocol) PROTOCOL="$2"; shift 2 ;;
        --SkipHardening) SKIP_HARDENING=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done
```

### Imports & Dependencies
- **PowerShell**: Do not use module imports; use `Add-Type -AssemblyName` for .NET types
- **Bash**: Do not use global includes; rely on system commands
- Resolve paths: PowerShell `$root = Split-Path`; Bash `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`

### Naming Conventions
- Files: lowercase-with-dashes (e.g., `r1-node-pair-watch.ps1`, `r1-node-pair-watch.sh`)
- Params: PascalCase PowerShell, `--CamelCase` Bash (e.g., `GatewayHost`, `--GatewayHost`)
- Functions: PascalCase Verb-Noun PowerShell, `snake_case` Bash
- Variables: `$camelCase` PowerShell, `$snake_case` Bash

### JSON Handling
- **PowerShell**: Build objects with `[ordered]@{}`; use `ConvertTo-Json -Depth 6`
- **Bash**: Use `jq` for all JSON operations; parse with `| jq -r '.field'`

### Best Practices
- Use `Out-Null` (PS) or `/dev/null` (Bash) to suppress expected output
- Log timestamps: `Get-Date -Format o` (PS) or `date -Iseconds` (Bash)
- Create directories lazily: `New-Item -ItemType Directory -Force` (PS) or `mkdir -p` (Bash)
- Avoid interactive I/O; prefer logging to files when needed
- Use colorized output: ANSI escape codes for consistent status display

## File Structure
```
├── setup-community-kit.ps1      # Main orchestration script (Windows)
├── setup-community-kit.sh       # Main orchestration script (Linux)
├── r1-openclaw-preflight.ps1    # Validation checks (Windows)
├── r1-openclaw-preflight.sh     # Validation checks (Linux)
├── r1-generate-qr.ps1           # QR payload generator (Windows)
├── r1-generate-qr.sh            # QR payload generator (Linux)
├── r1-node-pair-watch.ps1       # Pair approval watcher (Windows)
├── r1-node-pair-watch.sh        # Pair approval watcher (Linux)
├── install.sh                   # One-click Linux installation script
├── r1-gateway-payload.example.json
├── R1_OPENCLAW_SETUP_GUIDE.md   # Full documentation (general)
├── SETUP_LINUX_GUIDE.md         # Linux-specific setup guide
├── PUBLIC_RELEASE_CHECKLIST.md  # Pre-release review
├── AGENTS.md                    # This file
└── README.md                    # Project overview
```

## Security Notes

- Tokens stored in `~\openclaw\openclaw.json` (Windows) or `~/.openclaw/openclaw.json` (Linux)
- Never commit or screenshot real gateway tokens
- Use `r1-gateway-payload.example.json` for public examples
- Rotate tokens immediately if exposed
