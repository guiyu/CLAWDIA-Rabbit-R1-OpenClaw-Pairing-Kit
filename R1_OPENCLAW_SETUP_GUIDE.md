# Rabbit R1 + OpenClaw Community Setup Guide (Windows)

This guide is designed to help Rabbit R1 users connect to OpenClaw reliably, with Tailscale access and safer defaults.

## Important Disclaimers

- This guide is an independent community resource and is **not** affiliated with Rabbit, OpenClaw, Anthropic, OpenAI, or Tailscale.
- Follow these steps at your own risk; you are responsible for your own devices, credentials, and network exposure.
- This setup can expose services to your tailnet/internet if misconfigured; verify access controls before daily use.
- Upstream updates can change behavior; re-run preflight and security checks after upgrades.
- Never share real tokens, pairing payloads, or unredacted logs publicly.

## What This Kit Includes

- `setup-community-kit.ps1`: one-command preflight + hardening + QR generation.
- `r1-generate-qr.ps1`: generate a Rabbit-compatible QR payload and PNG.
- `r1-node-pair-watch.ps1`: watch for `node.pair` requests and approve quickly.
- `r1-openclaw-preflight.ps1`: preflight checks for OpenClaw, Tailscale, and hardening state.
- `r1-gateway-payload.example.json`: redacted payload for safe screenshots/posts.

## Architecture (Recommended)

- OpenClaw runs on your Windows host.
- Gateway auth mode uses token.
- Tailscale HTTPS funnel/serve exposes OpenClaw gateway to your tailnet.
- Rabbit R1 scans a `clawdbot-gateway` QR payload with your tailnet hostname and gateway token.

## Prerequisites

- Windows host with OpenClaw installed and working locally.
- Tailscale installed and logged in.
- Rabbit R1 on a network that can reach your tailnet URL.
- PowerShell opened as your normal user.

## 1) Preflight First

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\community\r1-openclaw-kit\r1-openclaw-preflight.ps1
```

This checks:

- OpenClaw CLI availability.
- Gateway health and status RPC.
- Tailscale command/status/serve mapping.
- Security hardening flags in `openclaw.json`.

### One-command setup (recommended)

```powershell
powershell -ExecutionPolicy Bypass -File .\community\r1-openclaw-kit\setup-community-kit.ps1 -GatewayHost "your-host.tailXXXXXXXX.ts.net"
```

## 2) Tailscale Setup

Confirm your tailnet hostname and open gateway port:

- Example local gateway target: `http://127.0.0.1:18789`
- Example tailnet host: `your-host.tailXXXXXXXX.ts.net`

Set serve mapping (adapt to your host/port):

```powershell
tailscale serve --https=443 --bg --set-path / http://127.0.0.1:18789
tailscale serve status
```

Notes:

- Keep OpenClaw bound locally and let Tailscale be the public ingress path.
- Use TLS (`wss`) in the QR payload.

## 3) Security Baseline (Do This Before Pairing)

Apply conservative defaults:

```powershell
openclaw config set gateway.auth.mode token
openclaw config set gateway.auth.allowTailscale true
openclaw config set gateway.trustedProxies '["127.0.0.1","::1"]'
openclaw config set tools.elevated.enabled false
openclaw config set browser.evaluateEnabled false
openclaw security audit --fix
openclaw gateway restart
openclaw security audit --deep --json
```

Token hygiene:

- Rotate token before sharing screenshots/logs:

```powershell
openclaw config set gateway.auth.token "$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex'))")"
openclaw gateway restart
```

- Never post real tokens in GitHub issues, Discord, or forum screenshots.

## 4) Generate Rabbit QR Payload + PNG

Run (replace host with your tailnet DNS name):

```powershell
powershell -ExecutionPolicy Bypass -File .\community\r1-openclaw-kit\r1-generate-qr.ps1 -GatewayHost "your-host.tailXXXXXXXX.ts.net" -Port 443 -Protocol wss -OutPng .\community\r1-openclaw-kit\r1-gateway-qr.png
```

What it outputs:

- JSON payload file: `r1-gateway-payload.json`
- PNG QR file: `r1-gateway-qr.png`

## 5) Pairing Flow (Critical Detail)

Rabbit-style QR pairing uses **node pairing** APIs.

Use this watcher in one terminal:

```powershell
powershell -ExecutionPolicy Bypass -File .\community\r1-openclaw-kit\r1-node-pair-watch.ps1 -TimeoutMinutes 10
```

Then on Rabbit R1:

1. On the Rabbit R1, open `Settings` -> `Device` -> `OpenClaw`.
2. Tap `Reset OpenClaw` (or remove the existing OpenClaw profile) so the device returns to QR scan mode.
3. If you are stuck in a reconnect loop, repeat reset once and confirm the old profile is gone.
4. Scan the newly generated QR.
5. Keep the pair watcher terminal open and wait for it to approve the `node.pair` request.
6. Confirm the R1 changes from connecting/pairing to connected.

Manual fallback commands:

```powershell
openclaw gateway call node.pair.list --json
openclaw gateway call node.pair.approve --params '{"requestId":"<id>"}' --json
```

## 6) Validate End-to-End

```powershell
openclaw gateway health
openclaw gateway call status --json
openclaw status --deep
```

If WhatsApp is configured, verify a test turn:

```powershell
openclaw agent --to +15551234567 --message "Respond exactly: gateway-model-test-ok" --json
```

## Troubleshooting Fast Paths

`gateway unreachable` on R1:

- Re-check tailnet hostname, port, and protocol (`wss`, `443`).
- Confirm `tailscale serve status` still maps to local gateway port.
- Confirm token in QR matches current `gateway.auth.token`.

`not-paired` in logs:

- Device identity changed; scan new QR and approve node pairing again.
- If needed, do the full R1 reset path: `Settings` -> `Device` -> `OpenClaw` -> `Reset OpenClaw`, then rescan.

Intermittent weird gateway state:

```powershell
openclaw gateway stop
openclaw gateway start
openclaw gateway health
```

## Community Sharing Checklist

- Redact token values from payload examples.
- Do not commit or publish `r1-gateway-payload.json` (it contains a live token).
- Share scripts and guide, not your personal `openclaw.json`.
- Include your OpenClaw version and platform in bug reports.
- Keep a recovery log for each setup attempt.
