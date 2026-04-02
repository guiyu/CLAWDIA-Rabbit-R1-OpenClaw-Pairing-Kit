#!/bin/bash
set -euo pipefail

# One-click setup script for Linux VPS

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    local status="$1"
    local msg="$2"
    local color
    case "$status" in
        PASS) color="$GREEN" ;;
        WARN) color="$YELLOW" ;;
        FAIL) color="$RED" ;;
        INFO) color="$CYAN" ;;
        *) color="$NC" ;;
    esac
    echo -e "${color}[$status] $msg${NC}"
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

print_status INFO "=== OpenClaw + R1 Setup (Linux) ==="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
GATEWAY_HOST=""
PORT=443
PROTOCOL="wss"
SKIP_HARDENING=false
NO_PNG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --GatewayHost|-H) GATEWAY_HOST="$2"; shift 2 ;;
        --Port|-P) PORT="$2"; shift 2 ;;
        --Protocol) PROTOCOL="$2"; shift 2 ;;
        --SkipHardening) SKIP_HARDENING=true ;;
        --NoPng) NO_PNG=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$GATEWAY_HOST" ]]; then
    read -p "Enter Tailscale Gateway Host (e.g., your-host.tailnet.ts.net): " GATEWAY_HOST
fi

if [[ -z "$GATEWAY_HOST" ]]; then
    print_status FAIL "GatewayHost is required"
    exit 1
fi

# Step 1: Preflight checks
echo ""
echo -e "${CYAN}== 1/3 Preflight checks ==${NC}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

check_pass() { print_status PASS "$1"; ((PASS_COUNT++)); }
check_warn() { print_status WARN "$1"; ((WARN_COUNT++)); }
check_fail() { print_status FAIL "$1"; ((FAIL_COUNT++)); }

if check_cmd openclaw; then
    check_pass "openclaw CLI found"
else
    check_fail "openclaw CLI not found in PATH"
fi

if check_cmd tailscale; then
    check_pass "tailscale CLI found"
else
    check_warn "tailscale CLI not found in PATH"
fi

# Gateway health check
if openclaw gateway health >/dev/null 2>&1; then
    check_pass "gateway health is OK"
else
    check_fail "gateway health check failed"
fi

# Gateway status JSON
if STATUS_RAW=$(openclaw gateway call status --json 2>/dev/null); then
    if echo "$STATUS_RAW" | jq empty 2>/dev/null; then
        check_pass "gateway status RPC returned valid JSON"
    else
        check_fail "gateway status RPC returned invalid JSON"
    fi
else
    check_fail "gateway status RPC failed"
fi

# Tailscale checks
if check_cmd tailscale; then
    if tailscale status >/dev/null 2>&1; then
        check_pass "tailscale status OK"
    else
        check_warn "tailscale status command failed"
    fi

    if SERVE_STATUS=$(tailscale serve status 2>&1); then
        if echo "$SERVE_STATUS" | grep -q "127\.0\.0\.1"; then
            check_pass "tailscale serve has localhost forwarding rules"
        else
            check_warn "tailscale serve status returned, but no localhost mapping detected"
        fi
    else
        check_warn "tailscale serve status failed: $SERVE_STATUS"
    fi
fi

# Config checks
CONFIG_PATH="$HOME/.openclaw/openclaw.json"
if [[ -f "$CONFIG_PATH" ]]; then
    if ! jq empty "$CONFIG_PATH" 2>/dev/null; then
        check_fail "invalid JSON in $CONFIG_PATH"
    else
        AUTH_MODE=$(jq -r '.gateway.auth.mode // empty' "$CONFIG_PATH")
        if [[ "$AUTH_MODE" == "token" ]]; then
            check_pass "gateway.auth.mode is token"
        else
            check_warn "gateway.auth.mode is '$AUTH_MODE' (recommended: token)"
        fi

        ALLOW_TS=$(jq -r '.gateway.auth.allowTailscale // empty' "$CONFIG_PATH")
        if [[ "$ALLOW_TS" == "true" ]]; then
            check_pass "gateway.auth.allowTailscale is true"
        else
            check_warn "gateway.auth.allowTailscale is not true"
        fi

        LOOPBACK_CHECK=$(jq -r '.gateway.trustedProxies // [] | contains(["127.0.0.1", "::1"])' "$CONFIG_PATH")
        if [[ "$LOOPBACK_CHECK" == "true" ]]; then
            check_pass "gateway.trustedProxies includes loopback"
        else
            check_warn "gateway.trustedProxies missing loopback IPs"
        fi

        ELEVATED=$(jq -r '.tools.elevated.enabled // false' "$CONFIG_PATH")
        if [[ "$ELEVATED" == "false" ]]; then
            check_pass "tools.elevated.enabled is false"
        else
            check_warn "tools.elevated.enabled is not false"
        fi

        BROWSER_EVAL=$(jq -r '.browser.evaluateEnabled // false' "$CONFIG_PATH")
        if [[ "$BROWSER_EVAL" == "false" ]]; then
            check_pass "browser.evaluateEnabled is false"
        else
            check_warn "browser.evaluateEnabled is not false"
        fi
    fi
else
    check_warn "config not found at $CONFIG_PATH"
fi

echo ""
if [[ $FAIL_COUNT -eq 0 ]]; then
    print_status PASS "Preflight complete: no blocking failures"
else
    print_status FAIL "Preflight complete: $FAIL_COUNT blocking failure(s)"
    exit 1
fi

# Step 2: Hardening
if [[ "$SKIP_HARDENING" != "true" ]]; then
    echo ""
    echo -e "${CYAN}== 2/3 Apply safe hardening defaults ==${NC}"
    
    openclaw config set gateway.auth.mode token
    openclaw config set gateway.auth.allowTailscale true
    openclaw config set gateway.trustedProxies '["127.0.0.1","::1"]'
    openclaw config set tools.elevated.enabled false
    openclaw config set browser.evaluateEnabled false
    openclaw security audit --fix
    openclaw gateway restart
    openclaw security audit --deep --json 2>/dev/null || true
    print_status PASS "Hardening applied"
else
    echo ""
    echo -e "${YELLOW}== 2/3 Hardening skipped (--SkipHardening) ==${NC}"
fi

# Step 3: Generate QR
echo ""
echo -e "${CYAN}== 3/3 Generate Rabbit QR payload ==${NC}"

# Create output directories
mkdir -p "$(dirname "$SCRIPT_DIR/r1-gateway-payload.json")"
mkdir -p "$(dirname "$SCRIPT_DIR/r1-gateway-qr.png")"

# Get gateway token
if TOKEN=$(openclaw gateway call settings --json 2>/dev/null | jq -r '.gateway.auth.token // empty'); then
    :
elif [[ -f "$CONFIG_PATH" ]]; then
    TOKEN=$(jq -r '.gateway.auth.token // empty' "$CONFIG_PATH")
else
    print_status FAIL "Could not find gateway token"
    exit 1
fi

# Build payload
JSON_PAYLOAD=$(jq -nc \
    --arg type 'clawdbot-gateway' \
    --argjson version 1 \
    --arg ips "$GATEWAY_HOST" \
    --argjson port "$PORT" \
    --arg token "$TOKEN" \
    --arg protocol "$PROTOCOL" \
    '{type: $type, version: $version, ips: [$ips], port: $port, token: $token, protocol: $protocol}')

# Save JSON
echo "$JSON_PAYLOAD" > "$SCRIPT_DIR/r1-gateway-payload.json"
print_status PASS "Payload JSON: $SCRIPT_DIR/r1-gateway-payload.json"

# Generate QR PNG
if [[ "$NO_PNG" != "true" ]]; then
    if command -v curl >/dev/null 2>&1; then
        ENCODED=$(printf '%s' "$JSON_PAYLOAD" | curl -g -G -w '' -o /dev/null -s --data-urlencode "text=" "https://quickchart.io/qr?size=900")
        # Proper URL encoding
        ENCODED=$(printf '%s' "$JSON_PAYLOAD" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read()))' 2>/dev/null || \
                  printf '%s' "$JSON_PAYLOAD" | xargs -0 -I{} urllib -e '{}' 2>/dev/null || \
                  printf '%s' "$JSON_PAYLOAD" | base64 | tr '+/' '-_')
        
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "
import urllib.parse
import urllib.request
json_data = '''$JSON_PAYLOAD'''
encoded = urllib.parse.quote(json_data)
url = f'https://quickchart.io/qr?size=900&text={encoded}'
try:
    urllib.request.urlretrieve(url, '$SCRIPT_DIR/r1-gateway-qr.png')
    print('QR PNG generated successfully')
except Exception as e:
    print(f'QR generation failed: {e}')
" 2>/dev/null || print_status WARN "QR PNG generation failed"
        elif command -v wget >/dev/null 2>&1; then
            ENCODED=$(printf '%s' "$JSON_PAYLOAD" | sed 's/ /%20/g; s/"/\\"/g; s/\\n/%0A/g')
            wget -q "https://quickchart.io/qr?size=900&text=$ENCODED" -O "$SCRIPT_DIR/r1-gateway-qr.png" 2>/dev/null || \
            print_status WARN "QR PNG generation failed"
        else
            print_status WARN "No QR generation tool available (needs python3 or wget/curl)"
        fi
        
        if [[ -f "$SCRIPT_DIR/r1-gateway-qr.png" ]]; then
            print_status PASS "QR PNG: $SCRIPT_DIR/r1-gateway-qr.png"
        fi
    else
        print_status WARN "curl not found, skipping QR PNG generation"
    fi
fi

echo ""
print_status PASS "Done!"
echo -e "${GREEN}Next step:${NC}"
echo "bash $SCRIPT_DIR/r1-node-pair-watch.sh --TimeoutMinutes 10"
