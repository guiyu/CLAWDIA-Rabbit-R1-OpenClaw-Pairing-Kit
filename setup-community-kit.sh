#!/bin/bash
set -euo pipefail

# One-click setup script for Linux VPS
# Supports both Tailscale and public IP modes

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
GATEWAY_HOST=""
PORT=443
PROTOCOL="wss"
SKIP_HARDENING=false
NO_PNG=false
MODE="tailscale"

# Initialize counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Helper to extract JSON from command output (handles console warnings)
extract_json() {
    echo "$1" | grep -o '{.*}' | tail -1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --GatewayHost|-H) GATEWAY_HOST="$2"; shift 2 ;;
        --Port|-P) PORT="$2"; shift 2 ;;
        --Protocol) PROTOCOL="$2"; shift 2 ;;
        --SkipHardening) SKIP_HARDENING=true ;;
        --NoPng) NO_PNG=true ;;
        --Mode) MODE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Ask for mode choice if not specified
if [[ -z "$MODE" ]]; then
    echo -e "${CYAN}Connection Mode:${NC}"
    echo "1. Tailscale (recommended for security)"
    echo "2. Public IP (direct exposure, requires firewall config)"
    read -p "Choose mode [1-2]: " MODE_CHOICE
    
    case $MODE_CHOICE in
        1) MODE="tailscale" ;;
        2) MODE="public" ;;
        *) MODE="public" ;;
    esac
fi

# Get gateway host based on mode
if [[ -z "$GATEWAY_HOST" ]]; then
    if [[ "$MODE" == "public" ]]; then
        PUBLIC_IP=$(curl -s4m 5 http://api4.ipify.org 2>/dev/null || echo "")
        if [[ -n "$PUBLIC_IP" ]]; then
            read -p "Use public IP $PUBLIC_IP as gateway host? [Y/n]: " VERIFY
            if [[ "$VERIFY" =~ ^[Yy]$ || -z "$VERIFY" ]]; then
                GATEWAY_HOST="$PUBLIC_IP"
            fi
        fi
        
        if [[ -z "$GATEWAY_HOST" ]]; then
            read -p "Enter your public IP address: " GATEWAY_HOST
        fi
        
        echo -e "${YELLOW}Note: Ensure firewall allows connections on port $PORT${NC}"
    else
        if command -v tailscale >/dev/null 2>&1; then
            read -p "Enter Tailscale Gateway Host (e.g., your-host.tailnet.ts.net): " GATEWAY_HOST
        else
            echo -e "${YELLOW}Tailscale not installed, using public IP mode${NC}"
            MODE="public"
            
            PUBLIC_IP=$(curl -s4m 5 http://api4.ipify.org 2>/dev/null || echo "")
            if [[ -n "$PUBLIC_IP" ]]; then
                read -p "Use public IP $PUBLIC_IP as gateway host? [Y/n]: " VERIFY
                if [[ "$VERIFY" =~ ^[Yy]$ || -z "$VERIFY" ]]; then
                    GATEWAY_HOST="$PUBLIC_IP"
                fi
            fi
            
            if [[ -z "$GATEWAY_HOST" ]]; then
                read -p "Enter your public IP address: " GATEWAY_HOST
            fi
        fi
    fi
fi

if [[ -z "$GATEWAY_HOST" ]]; then
    print_status FAIL "GatewayHost is required"
    exit 1
fi

# Step 1: Preflight checks
echo ""
echo -e "${CYAN}== 1/3 Preflight checks ==${NC}"

check_pass() { echo -e "${GREEN}[PASS] $1${NC}"; PASS_COUNT=$((PASS_COUNT+1)); }
check_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; WARN_COUNT=$((WARN_COUNT+1)); }
check_fail() { echo -e "${RED}[FAIL] $1${NC}"; FAIL_COUNT=$((FAIL_COUNT+1)); }

if command -v openclaw >/dev/null 2>&1; then
    check_pass "openclaw CLI found"
else
    check_fail "openclaw CLI not found in PATH"
fi

if openclaw gateway health >/dev/null 2>&1; then
    check_pass "gateway health is OK"
else
    check_fail "gateway health check failed"
fi

# Gateway status JSON - extract from noisy output
if STATUS_RAW=$(openclaw gateway call status --json 2>/dev/null); then
    STATUS_JSON=$(extract_json "$STATUS_RAW")
    if [[ -n "$STATUS_JSON" ]] && echo "$STATUS_JSON" | jq empty 2>/dev/null; then
        check_pass "gateway status RPC returned valid JSON"
    else
        check_fail "gateway status RPC returned invalid JSON"
    fi
else
    check_fail "gateway status RPC failed"
fi

# Config checks
CONFIG_PATH="$HOME/.openclaw/openclaw.json"
if [[ -f "$CONFIG_PATH" ]]; then
    if jq empty "$CONFIG_PATH" 2>/dev/null; then
        AUTH_MODE=$(jq -r '.gateway.auth.mode // empty' "$CONFIG_PATH")
        [[ "$AUTH_MODE" == "token" ]] && check_pass "gateway.auth.mode is token" || check_warn "gateway.auth.mode is '$AUTH_MODE' (recommended: token)"

        ALLOW_TS=$(jq -r '.gateway.auth.allowTailscale // empty' "$CONFIG_PATH")
        [[ "$ALLOW_TS" == "true" ]] && check_pass "gateway.auth.allowTailscale is true" || check_warn "gateway.auth.allowTailscale is not true"

        LOOPBACK_CHECK=$(jq -r '.gateway.trustedProxies // [] | contains(["127.0.0.1", "::1"])' "$CONFIG_PATH")
        [[ "$LOOPBACK_CHECK" == "true" ]] && check_pass "gateway.trustedProxies includes loopback" || check_warn "gateway.trustedProxies missing loopback IPs"

        ELEVATED=$(jq -r '.tools.elevated.enabled // false' "$CONFIG_PATH")
        [[ "$ELEVATED" == "false" ]] && check_pass "tools.elevated.enabled is false" || check_warn "tools.elevated.enabled is not false"

        BROWSER_EVAL=$(jq -r '.browser.evaluateEnabled // false' "$CONFIG_PATH")
        [[ "$BROWSER_EVAL" == "false" ]] && check_pass "browser.evaluateEnabled is false" || check_warn "browser.evaluateEnabled is not false"
    else
        check_fail "invalid JSON in $CONFIG_PATH"
    fi
else
    check_warn "config not found at $CONFIG_PATH"
fi

# Public IP mode warnings
if [[ "$MODE" == "public" ]]; then
    PUBLIC_IP=$(curl -s4m 5 http://api4.ipify.org 2>/dev/null || echo "unknown")
    [[ "$PUBLIC_IP" != "unknown" ]] && check_pass "Public IP available: $PUBLIC_IP" || check_warn "Could not detect public IP (using $GATEWAY_HOST)"
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
    
    if [[ "$MODE" == "public" ]]; then
        PUBLIC_IP=$(curl -s4m 5 http://api4.ipify.org 2>/dev/null || echo "")
        [[ -n "$PUBLIC_IP" ]] && openclaw config set gateway.trustedProxies "[\"127.0.0.1\",\"::1\",\"$PUBLIC_IP\"]"
        echo -e "${YELLOW}Configured for public IP mode${NC}"
        echo -e "${YELLOW}Important: Ensure your firewall allows port $PORT${NC}"
        echo -e "${YELLOW}Example: sudo ufw allow $PORT/tcp${NC}"
    fi
    
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

mkdir -p "$(dirname "$SCRIPT_DIR/r1-gateway-payload.json")"
mkdir -p "$(dirname "$SCRIPT_DIR/r1-gateway-qr.png")"

# Get gateway token - extract JSON from noisy output
if TOKEN=$(extract_json "$(openclaw gateway call settings --json 2>/dev/null)" | jq -r '.gateway.auth.token // empty'); then
    :
elif [[ -f "$CONFIG_PATH" ]]; then
    TOKEN=$(jq -r '.gateway.auth.token // empty' "$CONFIG_PATH")
else
    print_status FAIL "Could not find gateway token"
    exit 1
fi

JSON_PAYLOAD=$(jq -nc \
    --arg type 'clawdbot-gateway' \
    --argjson version 1 \
    --arg ips "$GATEWAY_HOST" \
    --argjson port "$PORT" \
    --arg token "$TOKEN" \
    --arg protocol "$PROTOCOL" \
    '{type: $type, version: $version, ips: [$ips], port: $port, token: $token, protocol: $protocol}')

echo "$JSON_PAYLOAD" > "$SCRIPT_DIR/r1-gateway-payload.json"
print_status PASS "Payload JSON: $SCRIPT_DIR/r1-gateway-payload.json"

if [[ "$NO_PNG" != "true" ]]; then
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import urllib.parse, urllib.request, sys
json_data = '''$JSON_PAYLOAD'''
encoded = urllib.parse.quote(json_data)
url = f'https://quickchart.io/qr?size=900&text={encoded}'
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as response:
        with open('$SCRIPT_DIR/r1-gateway-qr.png', 'wb') as f:
            f.write(response.read())
except Exception as e:
    print(f'Failed: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null && print_status PASS "QR PNG: $SCRIPT_DIR/r1-gateway-qr.png" || print_status WARN "QR PNG generation failed"
    elif command -v wget >/dev/null 2>&1; then
        ENCODED="$(printf '%s' "$JSON_PAYLOAD" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read()))' 2>/dev/null || echo "$JSON_PAYLOAD")"
        wget -q --user-agent="Mozilla/5.0" "https://quickchart.io/qr?size=900&text=$ENCODED" -O "$SCRIPT_DIR/r1-gateway-qr.png" 2>/dev/null && print_status PASS "QR PNG: $SCRIPT_DIR/r1-gateway-qr.png" || print_status WARN "QR PNG generation failed"
    else
        print_status WARN "No QR generation tool available (python3 or wget required)"
    fi
fi

echo ""
print_status PASS "Done!"
echo ""
echo -e "${GREEN}Connection mode:${NC} $MODE"
echo -e "${GREEN}Gateway host:${NC} $GATEWAY_HOST:$PORT"
echo ""
echo -e "${GREEN}Next step:${NC}"
if [[ "$MODE" == "tailscale" ]]; then
    echo "On Rabbit R1: Settings -> Device -> OpenClaw -> Reset OpenClaw -> Scan QR"
else
    echo "1. Ensure port $PORT is open in your firewall"
    echo "2. On Rabbit R1: Settings -> Device -> OpenClaw -> Reset OpenClaw -> Scan QR"
    echo -e "${YELLOW}Note: Rabbit R1 must be able to reach $GATEWAY_HOST:$PORT${NC}"
fi
echo ""
echo -e "${GREEN}Then run:${NC}"
echo "bash $SCRIPT_DIR/r1-node-pair-watch.sh --TimeoutMinutes 10"
