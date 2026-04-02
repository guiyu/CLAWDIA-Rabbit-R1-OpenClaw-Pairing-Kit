#!/bin/bash
# One-click installation script for Linux VPS
# Downloads and installs all scripts with proper permissions

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${CYAN}►$NC $1"; }
print_success() { echo -e "${GREEN}✓$NC $1"; }
print_warn() { echo -e "${YELLOW}✗$NC $1"; }
print_error() { echo -e "${RED}✗$NC $1"; }

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════╗"
echo "║   CLAWDIA - Rabbit R1 + OpenClaw (Linux Setup)    ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check dependencies
echo -e "${CYAN}Checking system dependencies...${NC}"

DEPENDENCIES_OK=true

for cmd in curl wget jq bash; do
    if command -v "$cmd" >/dev/null 2>&1; then
        print_success "$cmd found"
    else
        print_error "$cmd not found"
        DEPENDENCIES_OK=false
    fi
done

if [[ "$DEPENDENCIES_OK" != "true" ]]; then
    echo ""
    print_error "Missing dependencies. Installing..."
    
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq curl wget jq bash
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y -q curl wget jq bash
    elif command -v apk >/dev/null 2>&1; then
        apk update
        apk add --no-cache curl wget jq bash
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y -q curl wget jq bash
    else
        print_error "Unsupported package manager. Please install curl, wget, and jq manually."
        exit 1
    fi
fi

# Create installation directory
INSTALL_DIR="$HOME/.local/bin/clawdia-r1"
mkdir -p "$INSTALL_DIR"

echo ""
print_info "Downloading scripts to $INSTALL_DIR..."

# Download scripts from GitHub (adjust URL as needed)
# This assumes scripts are in the same repo - modify URL for your setup
SCRIPT_BASE_URL="https://raw.githubusercontent.com/YOUR_USERNAME/CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit/main"

declare -A SCRIPTS
SCRIPTS=(
    ["setup"]="setup-community-kit.sh"
    ["preflight"]="r1-openclaw-preflight.sh"
    ["watch"]="r1-node-pair-watch.sh"
    ["qr"]="r1-generate-qr.sh"
)

for key in "${!SCRIPTS[@]}"; do
    SCRIPT_URL="${SCRIPT_BASE_URL}/${SCRIPTS[$key]}"
    print_info "Downloading ${SCRIPTS[$key]}..."
    
    if command -v curl >/dev/null 2>&1; then
        curl -sL -o "$INSTALL_DIR/${SCRIPTS[$key]}" "$SCRIPT_URL" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$INSTALL_DIR/${SCRIPTS[$key]}" "$SCRIPT_URL" 2>/dev/null
    fi
    
    if [[ -f "$INSTALL_DIR/${SCRIPTS[$key]}" ]]; then
        chmod +x "$INSTALL_DIR/${SCRIPTS[$key]}"
        print_success "${SCRIPTS[$key]} installed"
    else
        print_error "Failed to download ${SCRIPTS[$key]}"
    fi
done

# Copy example payload
echo ""
print_info "Copying example payload..."
if [[ -f "$HOME/CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit/r1-gateway-payload.example.json" ]]; then
    cp "$HOME/CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit/r1-gateway-payload.example.json" "$INSTALL_DIR/"
    print_success "Example payload copied"
fi

# Add to PATH if not already
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    print_info "Adding to PATH..."
    
    if grep -q "$INSTALL_DIR" "$HOME/.bashrc" 2>/dev/null; then
        print_success "PATH already configured"
    else
        echo "" >> "$HOME/.bashrc"
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
        print_success "PATH added to ~/.bashrc"
        print_info "Run: source ~/.bashrc"
    fi
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Installation Complete!                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
print_success "Scripts installed to: $INSTALL_DIR"
echo ""
echo -e "${CYAN}Quick Start:${NC}"
echo "  # Run preflight check"
echo "  $INSTALL_DIR/preflight"
echo ""
echo "  # Full setup (requires Tailscale Gateway Host)"
echo "  $INSTALL_DIR/setup --GatewayHost your-host.tailnet.ts.net"
echo ""
echo "  # Start pair watcher (keep running during pairing)"
echo "  $INSTALL_DIR/watch --TimeoutMinutes 10"
echo ""
echo -e "For full documentation, see:"
echo "  https://github.com/YOUR_USERNAME/CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit"
echo ""
