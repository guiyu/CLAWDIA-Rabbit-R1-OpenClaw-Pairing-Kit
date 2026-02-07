# R1 + OpenClaw Community Kit

Plug-and-play scripts and docs for connecting Rabbit R1 to OpenClaw with Tailscale and safer defaults.

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
