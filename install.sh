#!/bin/bash
# One-click installation script for Linux VPS
# Copies local scripts to PATH

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

# Get script directory (where install.sh is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in the repository
if [[ ! -f "$SCRIPT_DIR/setup-community-kit.sh" ]]; then
    print_error "Run this script from the CLAWDIA repository directory"
    print_info "Expected to find scripts in: $SCRIPT_DIR"
    exit 1
fi

# Create installation directory
INSTALL_DIR="$HOME/.local/bin/clawdia-r1"
mkdir -p "$INSTALL_DIR"

echo ""
print_info "Installing scripts from $SCRIPT_DIR to $INSTALL_DIR..."

# Copy scripts (not download)
for script in setup-community-kit.sh r1-openclaw-preflight.sh r1-generate-qr.sh r1-node-pair-watch.sh; do
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        cp "$SCRIPT_DIR/$script" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$script"
        
        # Create alias/name without extension
        name="${script%.sh}"
        if [[ "$name" != $script ]]; then
            ln -sf "$INSTALL_DIR/$script" "$INSTALL_DIR/$name"
        fi
        print_success "$script -> $INSTALL_DIR/"
    else
        print_warn "Script not found: $script"
    fi
done

# Copy example payload
echo ""
print_info "Copying example payload..."
if [[ -f "$SCRIPT_DIR/r1-gateway-payload.example.json" ]]; then
    cp "$SCRIPT_DIR/r1-gateway-payload.example.json" "$INSTALL_DIR/"
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
echo "  $INSTALL_DIR/r1-openclaw-preflight"
echo ""
echo "  # Full setup (requires Tailscale Gateway Host)"
echo "  $INSTALL_DIR/setup --GatewayHost your-host.tailnet.ts.net"
echo ""
echo "  # Start pair watcher (keep running during pairing)"
echo "  $INSTALL_DIR/watch --TimeoutMinutes 10"
echo ""
echo -e "For full documentation, see:"
echo "  $(pwd)"
echo ""
