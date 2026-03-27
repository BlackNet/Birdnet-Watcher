# BirdNET-Go Watcher

BirdNET-Go Watcher is a lightweight Bash-based event processor that monitors
BirdNET-Go’s `actions.log` and sends species-specific Discord notifications
based on confidence thresholds, cooldown rules, and group classifications.

The script is designed for reliability, reproducibility, and unattended
operation on Linux systems (including systemd deployments).

---

## Features

- Watches BirdNET-Go’s `actions.log` in real time  
- Species grouped by behavior/type (raptors, owls, woodpeckers, etc.)  
- Per‑group confidence thresholds  
- Per‑species cooldown timers  
- Color‑coded Discord embeds  
- Debug mode for troubleshooting  
- `.env` support for secret management (Version 7.4+)  
- Fully systemd‑compatible (no leading whitespace, LF-only formatting)

---

## Version

**Current version:** `7.4`  
Changes from 7.3:  
- Added `.env` support for `WEBHOOK_URL`  
- Removed hardcoded webhook  
- No logic changes from 7.3  

Full changelog is included at the top of `watcher.sh`.

---

## Requirements

- Bash  
- `jq`  
- `curl`  
- BirdNET-Go installed and generating `actions.log`  
- A Discord webhook URL  

---

## .env Setup (Version 7.4+)

Create a `.env` file in the same directory as `watcher.sh`:

```bash
WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/xxxx"

