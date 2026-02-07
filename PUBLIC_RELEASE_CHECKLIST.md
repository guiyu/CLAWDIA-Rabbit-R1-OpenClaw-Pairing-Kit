# Public Release Checklist

Use this checklist before switching your repo to public.

## Privacy + Security

- [ ] Repo is private while doing final review.
- [ ] No real token values in any file.
- [ ] `r1-gateway-payload.json` is not committed.
- [ ] `.gitignore` includes `r1-gateway-payload.json`, `r1-gateway-qr.png`, and logs.
- [ ] No personal machine names or private hostnames in docs.

## Docs Quality (Noob-Friendly)

- [ ] README has a short beginner quickstart.
- [ ] Setup guide explains exact R1 reset path.
- [ ] Troubleshooting includes `gateway unreachable` and `not paired`.
- [ ] Disclaimers are visible and explicit.

## Functional Checks

- [ ] `r1-openclaw-preflight.ps1` runs cleanly.
- [ ] `setup-community-kit.ps1` runs with your test hostname.
- [ ] `r1-node-pair-watch.ps1` starts and exits correctly.
- [ ] QR payload generation works (`r1-generate-qr.ps1`).

## Publish

- [ ] Confirm final repo owner/name is correct.
- [ ] Set visibility to public.
- [ ] Add short repo description and topics.
- [ ] Create first release notes with known limitations.

## Recommended Repo Description

`Community kit for Rabbit R1 + OpenClaw pairing over Tailscale, with beginner-first setup and security hardening guidance.`
