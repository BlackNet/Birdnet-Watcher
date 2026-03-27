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
```
* Quotes are required
* .env must not be committed
* .gitignore should include .env
* If WEBHOOK_URL is missing or empty, the script will fail to send notifications.

  
---

## Running the Watcher
```bash
chmod +x watcher.sh
./watcher.sh
```

---

## systemd Service (Optional)
A sample service file is included in the repository.
Install it to:

```bash
/etc/systemd/system/birdnet-watcher.service
```
Then enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable birdnet-watcher
sudo systemctl start birdnet-watcher
```

---

## Logging & Debugging

```bash
DEBUG=true
```
to print detailed processing information, including:
* species matches.
* confidence checks.
* cooldown decisions.
* Discord send failures.

Successful Discord sends remain silent (HTTP 204).

---

## RGB color coding for Discord embeds

This section explains how BirdNET-Go Watcher assigns colors to Discord embeds
and how the numeric color values are derived. Discord requires embed colors as
a single **decimal integer**, not hex and not `R,G,B`.

---

## How the color number is derived

Discord uses 24‑bit RGB packed into one integer:

    color = (R * 65536) + (G * 256) + B

Where:

- **R** = red (0–255)  
- **G** = green (0–255)  
- **B** = blue (0–255)  

This is equivalent to taking a hex color like `#RRGGBB` and converting it to a
single decimal value.

### Examples

Red (`#FF0000`) Woodpeckers:

- R = 255, G = 0, B = 0  
- color = (255 * 65536) + (0 * 256) + 0  
- color = **16711680**

Blue (`#0000FF`) Raptors:

- R = 0, G = 0, B = 255  
- color = (0 * 65536) + (0 * 256) + 255  
- color = **255**

Green (`#00FF00`) Songbirds:

- R = 0, G = 255, B = 0  
- color = (0 * 65536) + (255 * 256) + 0  
- color = **65280**

Gold (`#FFD700`) Owls:

- R = 255, G = 215, B = 0  
- color = (255 * 65536) + (215 * 256) + 0  
- color = **16766720**

Magenta (`#FF00FF`) Hummingbird:

- R = 255, G = 0, B = 255  
- color = (255 * 65536) + (0 * 256) + 255  
- color = **16711935**

Teal (`#008080`) Ducks:

- R = 0, G = 128, B = 128  
- color = (0 * 65536) + (128 * 256) + 128  
- color = **32896**


---

## Colors currently in use

These are the colors used by the watcher’s species groups.

| Group       | Hex       | RGB (R,G,B)   | Decimal value |
|-------------|-----------|---------------|---------------|
| Woodpecker  | `#FF0000` | 255, 0, 0     | 16711680      |
| Raptor      | `#0000FF` | 0, 0, 255     | 255           |
| Songbird    | `#00FF00` | 0, 255, 0     | 65280         |
| Owl         | `#FFD700` | 255, 215, 0   | 16766720      |
| Hummingbird | `#FF00FF` | 255, 0, 255   | 16711935      |
| Duck        | `#008080` | 0, 128, 128   | 32896         |

These values appear in the script as:

    declare -A woodpecker=([color]=16711680)
    declare -A raptor=([color]=255)
    declare -A songbird=([color]=65280)
    declare -A owl=([color]=16766720)
    declare -A hummingbird=([color]=16711935)
    declare -A duck=([color]=32896)

---

## Verifying or adding colors

To verify a color:

1. Convert your hex color to R, G, B.
2. Apply:

       (R * 65536) + (G * 256) + B

3. Use that decimal value in the script and document it in this file.

Notes:

- Discord does **not** accept hex strings like `"#FF0000"`.
- Discord does **not** accept `"255,0,0"`.
- It only accepts the **decimal integer** between 0 and 16777215.

