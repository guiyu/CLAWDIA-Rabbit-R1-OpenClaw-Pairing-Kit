# CLAWDIA - Rabbit R1 + OpenClaw (Linux VPS Setup)

## Connection Modes

This toolkit supports two connection modes:

1. **Tailscale Mode** (Recommended for security): Uses Tailscale's private mesh network
2. **Public IP Mode**: Direct exposure via your VPS's public IP (requires firewall config)

## Quick Start

### Option 1: Tailscale Mode (Secure, Recommended)

**Prerequisites:**
```bash
# Install Tailscale on your VPS
curl -fsSL https://tailscale.com/install.sh | sh
tailscale login
```

**Run Setup:**
```bash
cd ~/CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit
chmod +x *.sh

# Run interactively (mode will be prompted)
./setup-community-kit.sh

# Or specify mode explicitly
./setup-community-kit.sh \
  --Mode tailscale \
  --GatewayHost "your-host.tailnet.ts.net" \
  --Port 443
```

### Option 2: Public IP Mode (VPS with public IP)

**Run Setup:**
```bash
cd ~/CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit

# Interactive mode (will prompt for IP)
./setup-community-kit.sh --Mode public

# Or specify public IP manually
./setup-community-kit.sh \
  --Mode public \
  --GatewayHost "your-public-ip.com" \
  --Port 443
```

**Configure Firewall:**
```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 443/tcp

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload

# AWS/Azure/GCP
# Configure security group/NSG to allow TCP 443
```

### One-Click Installation

```bash
# Install scripts to PATH (works with both modes)
./install.sh
source ~/.bashrc

# Then run any script from anywhere
preflight
setup --Mode public --GatewayHost your-ip.com
```

## Command Reference

### Setup Script

```bash
./setup-community-kit.sh [OPTIONS]

Options:
  --GatewayHost <host>  Required. Gateway host (Tailscale or public IP)
  --Port <number>       TCP port (default: 443)
  --Protocol <wss|ws>   WebSocket protocol (default: wss)
  --SkipHardening       Skip security hardening step
  --NoPng              Generate JSON only, skip QR code PNG
  --Mode <mode>         Connection mode: tailscale or public (default: prompt)
```

**Examples:**

```bash
# Tailscale with prompt for host
./setup-community-kit.sh --Mode tailscale

# Public IP direct
./setup-community-kit.sh --Mode public --GatewayHost 1.2.3.4

# Custom port
./setup-community-kit.sh --GatewayHost "myserver.ts.net" --Port 8443

# Skip hardening and skip QR PNG
./setup-community-kit.sh --GatewayHost "host.ts.net" --SkipHardening --NoPng
```

### Preflight Check

```bash
./r1-openclaw-preflight.sh [config_path]

# Check your setup before pairing
./r1-openclaw-preflight.sh

# Shows Tailscale status if available, or public IP detection
```

### Pair Watcher

```bash
./r1-node-pair-watch.sh [OPTIONS]

Options:
  --TimeoutMinutes <min>  Watch duration (default: 10)
  --PollSeconds <sec>     Poll interval (default: 1)
  --LogPath <path>        Log file path
```

**Example:**
```bash
./r1-node-pair-watch.sh --TimeoutMinutes 15 --PollSeconds 2
```

### QR Generator

```bash
./r1-generate-qr.sh [OPTIONS]

Options:
  --GatewayHost <host>  Required. Gateway host or public IP
  --Port <number>       TCP port (default: 443)
  --Protocol <wss|ws>   WebSocket protocol (default: wss)
  --NoPng              Skip PNG generation
```

## Troubleshooting

### Public IP Mode Issues

**Problem: Rabbit can't connect to gateway**
```bash
# Test connectivity from your network
curl -I https://your-public-ip:443

# Check gateway is listening
sudo ss -tlnp | grep 443

# Verify firewall
sudo ufw status  # or firewall-cmd --list-all
```

**Problem: Tailscale not needed**
- Preflight will skip Tailscale checks if not installed
- Use public IP mode if VPS has public IP
- No additional Tailscale configuration needed

### Gateway Health Check Fails

```bash
# Restart OpenClaw gateway
openclaw gateway restart

# Check gateway status
openclaw gateway health
```

### Config File Issues

Apply security hardening manually:
```bash
openclaw config set gateway.auth.mode token
openclaw config set gateway.auth.allowTailscale true
openclaw config set gateway.trustedProxies '["127.0.0.1","::1"]'
openclaw config set tools.elevated.enabled false
openclaw config set browser.evaluateEnabled false
openclaw security audit --fix
openclaw gateway restart
```

## Security Notes

**Tailscale Mode:**
- ✅ Private network, no public exposure
- ✅ Automatic encryption
- ✅ Recommended for security-conscious users

**Public IP Mode:**
- ⚠️ Gateway exposed to internet
- ⚠️ Ensure firewall restrictions
- ⚠️ Use strong authentication tokens
- ⚠️ Monitor for unusual access

**Token Security:**
- Never share real `gateway.auth.token` publicly
- Use `r1-gateway-payload.example.json` for screenshots
- Rotate tokens: `openclaw gateway generate-token`

## Quick Reference

```bash
# Tailscale setup
./setup-community-kit.sh --Mode tailscale --GatewayHost "host.ts.net"

# Public IP setup
./setup-community-kit.sh --Mode public --GatewayHost "1.2.3.4"

# Pair watcher
./r1-node-pair-watch.sh --TimeoutMinutes 10

# Check connection
./r1-openclaw-preflight.sh
```

## Disclaimers

- Community project, not affiliated with Rabbit/OpenClaw
- Use at your own risk
- No warranty provided
- Responsible for your security and data
- Rotate tokens if exposed
