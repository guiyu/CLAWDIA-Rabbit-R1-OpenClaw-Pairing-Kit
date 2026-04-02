# CLAWDIA - Rabbit R1 + OpenClaw (Linux VPS Setup)

## Quick Start

### One-Click Installation

```bash
# Clone or download to your VPS
cd ~
git clone https://github.com/YOUR_USERNAME/CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit.git
cd CLAWDIA-Rabbit-R1-OpenClaw-Pairing-Kit

# Make scripts executable
chmod +x *.sh

# Option 1: Run directly
./setup-community-kit.sh --GatewayHost "your-host.tailnet.ts.net"

# Option 2: Install to PATH (adds ~./local/bin/clawdia-r1)
./install.sh
source ~/.bashrc
setup --GatewayHost "your-host.tailnet.ts.net"
```

### Manual Installation Steps

#### 1. Prerequisites

Ensure your Linux VPS has:
- **bash** (version 4.0+)
- **curl** or **wget**
- **jq** (JSON parser)
- **openclaw** CLI installed
- **tailscale** CLI installed (recommended)

Install dependencies:
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y curl wget jq

# CentOS/RHEL
sudo yum install -y curl wget jq

# Alpine
apk update && apk add curl wget jq

# Fedora
sudo dnf install -y curl wget jq
```

#### 2. Verify OpenClaw Installation

```bash
# Check openclaw is installed
openclaw --version

# Check gateway health
openclaw gateway health

# Check config file exists
cat ~/.openclaw/openclaw.json
```

#### 3. Run Preflight Check

```bash
# Check system is ready
./r1-openclaw-preflight.sh

# Expected output: all [PASS] or expected [WARN] messages
```

#### 4. Run Tailscale (if using Tailscale)

```bash
# Login to Tailscale (if not already logged in)
tailscale up

# Verify Tailscale is running
tailscale status

# Check serve rules (if configured)
tailscale serve status
```

#### 5. Run Full Setup

```bash
# Main setup script
./setup-community-kit.sh \
  --GatewayHost "your-host.tailnet.ts.net" \
  --Port 443 \
  --Protocol wss
```

This will:
1. Run preflight checks
2. Apply security hardening (can skip with `--SkipHardening`)
3. Generate QR payload and PNG image

#### 6. Start Pair Watcher

In a **separate terminal**:

```bash
# Start the pair approval watcher
./r1-node-pair-watch.sh --TimeoutMinutes 10 --PollSeconds 1
```

Keep this terminal open - it will automatically approve pairing requests from your Rabbit R1.

#### 7. Pair Your Rabbit R1

On your Rabbit R1 device:
1. Go to **Settings** → **Device** → **OpenClaw**
2. Select **Reset OpenClaw** (if previously paired)
3. Choose **Scan QR Code**
4. Scan the QR code from `r1-gateway-qr.png`

The pair watcher will detect and approve the request automatically.

---

## Command Reference

### Setup Script

```bash
./setup-community-kit.sh [OPTIONS]

Options:
  --GatewayHost <host>  Required. Tailscale gateway host (e.g., your-host.tailnet.ts.net)
  --Port <number>       TCP port (default: 443)
  --Protocol <wss|ws>   WebSocket protocol (default: wss)
  --SkipHardening       Skip security hardening step
  --NoPng              Generate JSON only, skip QR code PNG
```

**Example:**
```bash
./setup-community-kit.sh --GatewayHost "myserver.tailnet.ts.net" --Port 443
```

### Preflight Script

```bash
./r1-openclaw-preflight.sh [config_path]

Arguments:
  config_path  Path to openclaw.json (default: ~/.openclaw/openclaw.json)
```

**Example:**
```bash
./r1-openclaw-preflight.sh ~/.openclaw/openclaw.json
```

### Pair Watcher

```bash
./r1-node-pair-watch.sh [OPTIONS]

Options:
  --TimeoutMinutes <min>  Watch duration in minutes (default: 10)
  --PollSeconds <sec>     Poll interval in seconds (default: 1)
  --LogPath <path>        Log file path (default: ./.r1-pair-watch/r1-node-pair-watch.log)
```

**Example:**
```bash
./r1-node-pair-watch.sh --TimeoutMinutes 15 --PollSeconds 2
```

### QR Generator

```bash
./r1-generate-qr.sh [OPTIONS]

Options:
  --GatewayHost <host>  Required. Tailscale gateway host
  --Port <number>       TCP port (default: 443)
  --Protocol <wss|ws>   WebSocket protocol (default: wss)
  --OutJson <path>      Output JSON file path
  --OutPng <path>       Output PNG file path
  --NoPng              Skip PNG generation
```

**Example:**
```bash
./r1-generate-qr.sh --GatewayHost "myserver.ts.net" --OutJson ~/payload.json
```

---

## Troubleshooting

### Gateway Health Check Fails

```bash
# Check openclaw service status
sudo systemctl status openclaw  # if using systemd

# Restart gateway
openclaw gateway restart

# Check for errors
openclaw gateway health
openclaw gateway logs
```

### Tailscale Not Found

```bash
# Install Tailscale on Linux
curl -fsSL https://tailscale.com/install.sh | sh

# Login with your auth key
tailscale up --authkey=tskey-auth-YOUR_AUTH_KEY

# Verify connection
tailscale status
```

### QR Code Not Scanning

1. Verify the gateway host is accessible from Rabbit R1's network
2. Check that Tailscale serve rules allow R1 access
3. Regenerate the QR code:
   ```bash
   ./r1-generate-qr.sh --GatewayHost "your-host.tailnet.ts.net"
   ```
4. Ensure R1 is on the same Tailscale network

### Pair Watcher Times Out

- **Increase timeout**: `--TimeoutMinutes 20`
- **Check logs**: `cat ./.r1-pair-watch/r1-node-pair-watch.log`
- **Verify gateway is responding**: 
  ```bash
  openclaw gateway call node.pair.list --json
  ```

### Config File Issues

The config file is typically at `~/.openclaw/openclaw.json`.

To fix common configuration issues:

```bash
# Apply security hardening
openclaw config set gateway.auth.mode token
openclaw config set gateway.auth.allowTailscale true
openclaw config set gateway.trustedProxies '["127.0.0.1","::1"]'
openclaw config set tools.elevated.enabled false
openclaw config set browser.evaluateEnabled false
openclaw security audit --fix
openclaw gateway restart
```

---

## Security Notes

- **Never share** real `gateway.auth.token` in screenshots or public posts
- Use `r1-gateway-payload.example.json` for public examples
- Tokens are stored in `~/.openclaw/openclaw.json` - protect this file
- Rotate tokens immediately if exposed:
  ```bash
  openclaw gateway generate-token
  ```

---

## File Structure

```
~/.local/bin/clawdia-r1/       # Installed scripts (if using install.sh)
├── setup-community-kit.sh
├── r1-openclaw-preflight.sh
├── r1-generate-qr.sh
├── r1-node-pair-watch.sh
├── r1-gateway-payload.example.json

./                              # Working directory
├── r1-gateway-payload.json     # Generated QR payload
├── r1-gateway-qr.png           # Generated QR code image
└── .r1-pair-watch/
    └── r1-node-pair-watch.log  # Pair watcher log file
```

---

## Support & Resources

- **Documentation**: View `R1_OPENCLAW_SETUP_GUIDE.md` for comprehensive guide
- **Example Payload**: See `r1-gateway-payload.example.json` for format reference
- **Release Checklist**: See `PUBLIC_RELEASE_CHECKLIST.md` for safe sharing guidelines

---

## Disclaimers

- This is a **community project**, not affiliated with Rabbit, OpenClaw, Anthropic, OpenAI, or Tailscale
- Use all scripts and configuration changes **at your own risk**
- No warranty is provided
- You are responsible for your own device, account, network, token, and data security
- Always rotate tokens if they are exposed
