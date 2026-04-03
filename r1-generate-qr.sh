#!/bin/bash
set -euo pipefail

# QR generation script for Linux

GATEWAY_HOST=""
PORT=443
PROTOCOL="wss"
OUT_JSON=""
OUT_PNG=""
NO_PNG=false

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --GatewayHost) GATEWAY_HOST="$2"; shift 2 ;;
        --Port) PORT="$2"; shift 2 ;;
        --Protocol) PROTOCOL="$2"; shift 2 ;;
        --OutJson) OUT_JSON="$2"; shift 2 ;;
        --OutPng) OUT_PNG="$2"; shift 2 ;;
        --NoPng) NO_PNG=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$GATEWAY_HOST" ]]; then
    echo "Error: --GatewayHost is required"
    exit 1
fi

# Default output paths
OUT_JSON="${OUT_JSON:-$SCRIPT_DIR/r1-gateway-payload.json}"
OUT_PNG="${OUT_PNG:-$SCRIPT_DIR/r1-gateway-qr.png}"

# Create output directories
mkdir -p "$(dirname "$OUT_JSON")"
mkdir -p "$(dirname "$OUT_PNG")"

get_token() {
    local CFG_PATH="$HOME/.openclaw/openclaw.json"
    
    # Try API first
    if TOKEN=$(openclaw gateway call settings --json 2>/dev/null | jq -r '.gateway.auth.token // empty'); then
        echo "$TOKEN"
        return 0
    fi
    
    # Fallback to config file
    if [[ -f "$CFG_PATH" ]]; then
        TOKEN=$(jq -r '.gateway.auth.token // empty' "$CFG_PATH")
        if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
            echo "$TOKEN"
            return 0
        fi
    fi
    
    echo "Error: Could not find gateway.token" >&2
    return 1
}

echo "Getting gateway token..."
if ! TOKEN=$(get_token); then
    echo "$TOKEN" >&2
    exit 1
fi

# Build JSON payload
JSON_PAYLOAD=$(jq -nc \
    --arg type 'clawdbot-gateway' \
    --argjson version 1 \
    --arg ips "$GATEWAY_HOST" \
    --argjson port "$PORT" \
    --arg token "$TOKEN" \
    --arg protocol "$PROTOCOL" \
    '{type: $type, version: $version, ips: [$ips], port: $port, token: $token, protocol: $protocol}')

# Save JSON
echo "$JSON_PAYLOAD" > "$OUT_JSON"
echo "Payload JSON: $OUT_JSON"

# Generate QR PNG if requested
if [[ "$NO_PNG" != "true" ]]; then
    echo "Generating QR PNG..."
    
    # Use python3 if available
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "
import urllib.parse
import urllib.request
import sys

json_data = '''$JSON_PAYLOAD'''
encoded = urllib.parse.quote(json_data)
url = f'https://quickchart.io/qr?size=900&text={encoded}'

try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as response:
        with open('$OUT_PNG', 'wb') as f:
            f.write(response.read())
    print('QR PNG generated successfully')
except Exception as e:
    print(f'QR generation failed: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
        echo "QR PNG: $OUT_PNG"
    else
        echo "Warning: QR PNG generation failed" >&2
    fi
elif command -v wget >/dev/null 2>&1; then
    ENCODED=$(printf '%s' "$JSON_PAYLOAD" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read()))' 2>/dev/null || echo "$JSON_PAYLOAD")
    wget -q --user-agent="Mozilla/5.0" "https://quickchart.io/qr?size=900&text=$ENCODED" -O "$OUT_PNG" 2>/dev/null && \
    echo "QR PNG: $OUT_PNG" || \
    echo "Warning: QR PNG generation failed" >&2
else
    echo "Warning: No QR generation tool available (python3 or wget required)" >&2
    fi
fi

echo "Done. Keep token private when sharing files/screenshots."
