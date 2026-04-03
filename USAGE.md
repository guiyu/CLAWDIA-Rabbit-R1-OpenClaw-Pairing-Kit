# CLAWDIA - Usage Guide (Linux VPS)

## Quick Start

### 1. Install Scripts to PATH

```bash
./install.sh
source ~/.bashrc
```

Scripts are installed to `~/.local/bin/clawdia-r1/` and available from anywhere.

### 2. Run Preflight Check

```bash
r1-openclaw-preflight
# or
~/.local/bin/clawdia-r1/r1-openclaw-preflight
```

Checks: openclaw CLI, gateway health, Tailscale status (optional).

### 3. Setup Gateway

**Public IP Mode** (default for VPS without Tailscale):

```bash
setup-community-kit --Mode public --GatewayHost "YOUR_PUBLIC_IP" --Port 18789
```

**Tailscale Mode** (if installed):

```bash
setup-community-kit --Mode tailscale --GatewayHost "your-host.tailnet.ts.net" --Port 443
```

This will:
- Run preflight checks
- Apply security hardening (token auth, trusted proxies, disable elevated tools)
- Generate QR payload JSON and PNG

### 4. Generate QR Code (Standalone)

```bash
r1-generate-qr --GatewayHost "YOUR_PUBLIC_IP" --Port 18789 --Protocol ws
```

Options:
- `--GatewayHost` (required): Public IP or Tailscale hostname
- `--Port` (default: 443): Gateway port
- `--Protocol` (default: wss): Use `ws` for non-TLS, `wss` for TLS
- `--NoPng`: Generate JSON only, skip PNG
- `--OutJson <path>`: Custom JSON output path
- `--OutPng <path>`: Custom PNG output path

Output files:
- `~/.local/bin/clawdia-r1/r1-gateway-payload.json`
- `~/.local/bin/clawdia-r1/r1-gateway-qr.png`

### 5. Pair Rabbit R1

**Start the pair watcher first:**

```bash
r1-node-pair-watch --TimeoutMinutes 10
```

**Then on Rabbit R1:**
1. Open `Settings` → `Device` → `OpenClaw`
2. Tap `Reset OpenClaw`
3. Scan the QR code (`r1-gateway-qr.png`)
4. Keep the watcher terminal open
5. Watcher will auto-approve the pairing request

### 6. Validate Connection

```bash
openclaw gateway health
openclaw gateway call status --json
```

## Manual Commands

### Security Hardening

```bash
openclaw config set gateway.auth.mode token
openclaw config set gateway.auth.allowTailscale true
openclaw config set gateway.trustedProxies '["127.0.0.1","::1"]'
openclaw config set tools.elevated.enabled false
openclaw config set browser.evaluateEnabled false
openclaw security audit --fix
openclaw gateway restart
```

### Rotate Token

```bash
openclaw config set gateway.auth.token "$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex'))")"
openclaw gateway restart
```

Then regenerate QR with the new token.

### Manual Pair Approval

```bash
# List pending pair requests
openclaw gateway call node.pair.list --json

# Approve a specific request
openclaw gateway call node.pair.approve --params '{"requestId":"<id>"}' --json
```

### Restart Gateway

```bash
openclaw gateway restart
# or
openclaw gateway stop
openclaw gateway start
```

## Troubleshooting

### Gateway Not Listening

```bash
# Check if gateway is running
ps aux | grep openclaw

# Check listening ports
ss -tlnp | grep openclaw

# Restart if needed
openclaw gateway restart
```

### QR Scan Fails

- Verify the IP/hostname in the QR matches your server
- Check the port matches the gateway's actual listening port (default: 18789)
- Use `ws` protocol for direct IP, `wss` for Tailscale/TLS
- Regenerate QR after any config change

### Pairing Timeout

- Ensure the pair watcher is running **before** scanning the QR
- Increase timeout: `r1-node-pair-watch --TimeoutMinutes 15`
- Check logs: `cat ~/.local/bin/clawdia-r1/.r1-pair-watch/r1-node-pair-watch.log`

### Feishu Plugin Warnings

If you see `Cannot find module 'zod'` from the feishu plugin:

```bash
openclaw config set 'plugins.entries.feishu.enabled' false
openclaw gateway restart
```

### Config Token Corruption

If `openclaw config set` corrupts the token (due to CLI warnings in output), fix manually:

```bash
# Generate new token
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Edit ~/.openclaw/openclaw.json and set gateway.auth.token to the new value
# Then restart:
openclaw gateway restart
```

## Script Options Reference

### setup-community-kit.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--GatewayHost` | Gateway host (IP or hostname) | Prompted |
| `--Port` | TCP port | 443 |
| `--Protocol` | WebSocket protocol | wss |
| `--Mode` | Connection mode: `tailscale` or `public` | Prompted |
| `--SkipHardening` | Skip security hardening | false |
| `--NoPng` | Skip QR PNG generation | false |

### r1-node-pair-watch.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--TimeoutMinutes` | Watch duration | 10 |
| `--PollSeconds` | Poll interval | 1 |
| `--LogPath` | Custom log path | Auto |

### r1-generate-qr.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--GatewayHost` | Required. Gateway host | - |
| `--Port` | TCP port | 443 |
| `--Protocol` | WebSocket protocol | wss |
| `--NoPng` | Skip PNG generation | false |
| `--OutJson` | Custom JSON path | Auto |
| `--OutPng` | Custom PNG path | Auto |

## Security Notes

- Never share `r1-gateway-payload.json` publicly (contains live token)
- Use `r1-gateway-payload.example.json` for screenshots
- Rotate tokens immediately if exposed
- Keep firewall configured to allow only necessary ports
- Review `PUBLIC_RELEASE_CHECKLIST.md` before sharing
