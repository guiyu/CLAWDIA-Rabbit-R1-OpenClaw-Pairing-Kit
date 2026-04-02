#!/bin/bash
set -euo pipefail

# Preflight check script for Linux

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

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

check_pass() { print_status PASS "$1"; ((PASS_COUNT++)); }
check_warn() { print_status WARN "$1"; ((WARN_COUNT++)); }
check_fail() { print_status FAIL "$1"; ((FAIL_COUNT++)); }

print_status INFO "=== OpenClaw + R1 Preflight ==="
CONFIG_PATH="${1:-$HOME/.openclaw/openclaw.json}"

# Check openclaw CLI
if command -v openclaw >/dev/null 2>&1; then
    check_pass "openclaw CLI found at $(command -v openclaw)"
else
    check_fail "openclaw CLI not found in PATH"
fi

# Check tailscale CLI (optional)
if command -v tailscale >/dev/null 2>&1; then
    check_pass "tailscale CLI found at $(command -v tailscale)"
else
    check_warn "tailscale CLI not found in PATH (optional, skip if using public IP)"
fi

# Gateway health check
if openclaw gateway health >/dev/null 2>&1; then
    check_pass "gateway health is OK"
else
    check_fail "gateway health check failed"
fi

# Gateway status RPC
if STATUS_RAW=$(openclaw gateway call status --json 2>/dev/null); then
    if echo "$STATUS_RAW" | jq empty 2>/dev/null; then
        check_pass "gateway status RPC returned valid JSON"
    else
        check_fail "gateway status RPC returned invalid JSON"
    fi
else
    check_fail "gateway status RPC failed"
fi

# Tailscale status (optional)
if command -v tailscale >/dev/null 2>&1; then
    if tailscale status >/dev/null 2>&1; then
        check_pass "tailscale status OK"
    else
        check_warn "tailscale status command failed"
    fi

    if SERVE_STATUS=$(tailscale serve status 2>&1); then
        if echo "$SERVE_STATUS" | grep -q "127\.0\.0\.1"; then
            check_pass "tailscale serve has localhost forwarding rule(s)"
        else
            check_warn "tailscale serve status returned, but no explicit localhost mapping detected"
        fi
    else
        check_warn "tailscale serve status failed: $SERVE_STATUS"
    fi
fi

# Public IP check (alternative to Tailscale)
if ! command -v tailscale >/dev/null 2>&1; then
    PUBLIC_IP=$(curl -s4m 5 http://api4.ipify.org 2>/dev/null || curl -s4m 5 http://ipinfo.io/ip 2>/dev/null || echo "unknown")
    if [[ "$PUBLIC_IP" != "unknown" ]]; then
        check_pass "Public IP available: $PUBLIC_IP (using public IP mode)"
    else
        check_warn "No public IP detected (ensure firewall allows port $PORT)"
    fi
fi

# Config validation
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
            check_pass "gateway.trustedProxies includes loopback IPv4 and IPv6"
        else
            check_warn "gateway.trustedProxies missing 127.0.0.1 and/or ::1"
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
    exit 0
else
    print_status FAIL "Preflight complete: $FAIL_COUNT blocking failure(s)"
    exit 1
fi
