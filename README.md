# R1 + OpenClaw Community Kit

Plug-and-play scripts and docs for connecting Rabbit R1 to OpenClaw with Tailscale and safer defaults.

## Disclaimers

- This is an independent community project and is **not** affiliated with Rabbit, OpenClaw, Anthropic, OpenAI, or Tailscale.
- Use all scripts and configuration changes at your own risk.
- You are responsible for your own device, account, network, token, and data security.
- No warranty is provided; this kit may break with upstream updates or account policy changes.
- Always rotate tokens if they are exposed and avoid posting secrets in screenshots/logs.

## Beginner Mode (Start Here)

If you are new, do these exact steps in order:

1. Open PowerShell.
2. Go to this folder:

```powershell
cd C:\path\to\r1-openclaw-kit
```

3. Run the one-command setup:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-community-kit.ps1 -GatewayHost "your-host.tailnet.ts.net"
```

4. Start the pairing watcher (keep this terminal open):

```powershell
powershell -ExecutionPolicy Bypass -File .\r1-node-pair-watch.ps1 -TimeoutMinutes 10
```

5. On Rabbit R1, go to `Settings` -> `Device` -> `OpenClaw` -> `Reset OpenClaw`, then scan the QR.

If one step fails, stop there and fix that step before moving on.

## Mascot

 Lobster gal with bunny ears:

![CLAWDIA mascot](./Clawdia.png)

```text
 __________________/\\\\\\\\\__/\\\_________________/\\\\\\\\\_____/\\\______________/\\\__/\\\\\\\\\\\\_____/\\\\\\\\\\\_____/\\\\\\\\\______________         
  _______________/\\\////////__\/\\\_______________/\\\\\\\\\\\\\__\/\\\_____________\/\\\_\/\\\////////\\\__\/////\\\///____/\\\\\\\\\\\\\____________        
   _____________/\\\/___________\/\\\______________/\\\/////////\\\_\/\\\_____________\/\\\_\/\\\______\//\\\_____\/\\\______/\\\/////////\\\___________       
    ____________/\\\_____________\/\\\_____________\/\\\_______\/\\\_\//\\\____/\\\____/\\\__\/\\\_______\/\\\_____\/\\\_____\/\\\_______\/\\\___________      
     ___________\/\\\_____________\/\\\_____________\/\\\\\\\\\\\\\\\__\//\\\__/\\\\\__/\\\___\/\\\_______\/\\\_____\/\\\_____\/\\\\\\\\\\\\\\\___________     
      ___________\//\\\____________\/\\\_____________\/\\\/////////\\\___\//\\\/\\\/\\\/\\\____\/\\\_______\/\\\_____\/\\\_____\/\\\/////////\\\___________    
       ____________\///\\\__________\/\\\_____________\/\\\_______\/\\\____\//\\\\\\//\\\\\_____\/\\\_______/\\\______\/\\\_____\/\\\_______\/\\\___________   
        ______________\////\\\\\\\\\_\/\\\\\\\\\\\\\\\_\/\\\_______\/\\\_____\//\\\__\//\\\______\/\\\\\\\\\\\\/____/\\\\\\\\\\\_\/\\\_______\/\\\___________  
         _________________\/////////__\///////////////__\///________\///_______\///____\///_______\////////////_____\///////////__\///________\///____________ 
```

## Included

- `R1_OPENCLAW_SETUP_GUIDE.md` - full walkthrough and troubleshooting.
- `setup-community-kit.ps1` - one-command preflight + hardening + QR generation.
- `r1-openclaw-preflight.ps1` - validates host setup.
- `r1-generate-qr.ps1` - builds Rabbit-compatible QR payload.
- `r1-node-pair-watch.ps1` - approves `node.pair` requests quickly.
- `r1-gateway-payload.example.json` - screenshot-safe example payload.
- `PUBLIC_RELEASE_CHECKLIST.md` - pre-public checklist for safe sharing.

## Fast Start

From this folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-community-kit.ps1 -GatewayHost "your-host.tailnet.ts.net"
powershell -ExecutionPolicy Bypass -File .\r1-node-pair-watch.ps1 -TimeoutMinutes 10
```

Optional flags:

- `-SkipHardening`: run checks + QR generation only.
- `-NoPng`: create JSON payload only (no image download).

## Safe Sharing Rules

- Never share a real `gateway.auth.token`.
- Use `r1-gateway-payload.example.json` for screenshots/posts.
- If you accidentally leak a token, rotate it immediately.

## Noob-Friendly Notes

- You do **not** need to understand every script first; run preflight and follow prompts.
- `r1-openclaw-preflight.ps1` only checks status; it does not pair your device.
- `setup-community-kit.ps1` can apply hardening defaults automatically.
- `r1-node-pair-watch.ps1` is time-limited and exits on success or timeout.

## If You Get Stuck

1. Re-run preflight:

```powershell
powershell -ExecutionPolicy Bypass -File .\r1-openclaw-preflight.ps1
```

2. If R1 says `gateway unreachable`, verify `tailscale serve status` and regenerate QR.
3. If R1 says `not paired`, do full reset (`Settings` -> `Device` -> `OpenClaw` -> `Reset OpenClaw`) and pair again.
4. Use the full guide: `R1_OPENCLAW_SETUP_GUIDE.md`.
