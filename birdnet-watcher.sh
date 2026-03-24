#!/bin/bash
# ============================================================
# BirdNET-Go Watcher — Version 7.4
#
# ===================== CHANGELOG ============================
#
# Version 1:
#   - Initial stable version
#   - Lowercase species lists
#   - Strict raw matching (no normalization)
#   - Group-based confidence thresholds
#   - Cooldown system
#   - Full debug mode (all events logged)
#
# Version 2:
#   - Removed DEFAULT_CONFIDENCE
#   - Strict per-group confidence enforcement
#   - Debug error if group missing confidence
#
# Version 3:
#   - Set all group confidence thresholds to 0.20
#   - Increased detection volume for debugging
#
# Version 4:
#   - Only log failed Discord sends
#   - Successful sends (HTTP 204) are silent
#   - On failure: print payload, HTTP code, and response body
#   - Updated DEBUG flag to true/false
#   - Added full cumulative changelog
#
# Version 5:
#   - STRICT MODE: Unmatched species are silently skipped
#   - DEFAULT_GROUP no longer used for classification
#   - Unmatched species do NOT update cooldown
#   - Northern cardinal moved to raptor group (for testing)
#
# Version 6:
#   - Added dedicated OWL group (logic change)
#   - Owl group uses GOLD color (#FFD700 → 16766720)
#   - Added all region-appropriate owls:
#       eastern screech-owl
#       barred owl
#       great horned owl
#       barn owl
#       short-eared owl
#       long-eared owl
#   - Owls removed from raptor group
#
# Version 7:
#   - Added systemd service support
#   - Script validated for /usr/local/bin execution
#   - Ensured correct shebang at byte 0 (no leading blank lines)
#   - LF-only formatting for systemd compatibility
#
# Version 7.3:
#   - Added confidence normalization:
#       * Skip null confidence
#       * Skip missing confidence
#       * Convert string confidence ("0.42") to float
#       * Prevent 0.00% errors
#       * Ensure consistent behavior across all groups
#   - No logic changes beyond confidence handling
#
# Version 7.4:
#   - Added .env support for WEBHOOK_URL
#   - Removed hardcoded webhook secret
#   - No logic changes from Version 7.3
#
# ============================================================

# ============================================================
# .env file requirements:
#   • Must exist in the same directory as this script
#   • Must contain the following line:
#         WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/xxxx"
#   • Quotes are required
#   • .env must NOT be committed to GitHub
# ============================================================

# Load secrets from .env if present
if [[ -f ".env" ]]; then
    source ".env"
fi

############################################################
# USER CONFIGURATION
############################################################

LOG=/root/birdnet-go-app/data/logs/actions.log
LOCATION="East Alabama"

COOLDOWN=60
DEBUG=true

############################################################
# GROUP DEFINITIONS (ALL LOWERCASE)
############################################################

declare -A woodpecker=(
  [color]=16711680
  [confidence]=0.20
)
woodpecker_names=(
  "red-bellied woodpecker"
  "downy woodpecker"
  "hairy woodpecker"
  "pileated woodpecker"
  "northern flicker"
  "yellow-bellied sapsucker"
  "red-cockaded woodpecker"
  "red-headed woodpecker"
)

declare -A raptor=(
  [color]=255
  [confidence]=0.20
)
raptor_names=(
  "red-tailed hawk"
  "cooper's hawk"
  "sharp-shinned hawk"
  "red-shouldered hawk"
  "northern cardinal"
  "bald eagle"
  "osprey"
)

declare -A owl=(
  [color]=16766720
  [confidence]=0.20
)
owl_names=(
  "eastern screech-owl"
  "barred owl"
  "great horned owl"
  "barn owl"
  "short-eared owl"
  "long-eared owl"
)

declare -A songbird=(
  [color]=65280
  [confidence]=0.95
)
songbird_names=(
  "eastern phoebe"
  "blue jay"
  "eastern bluebird"
  "carolina chickadee"
  "american goldfinch"
)

declare -A hummingbird=(
  [color]=16711935
  [confidence]=0.20
)
hummingbird_names=(
  "ruby-throated hummingbird"
)

declare -A duck=(
  [color]=32896
  [confidence]=0.10
)
duck_names=(
  "mallard"
  "wood duck"
  "common yellowthroat"
  "hooded merganser"
  "canada goose"
)

############################################################
# INTERNAL SETUP
############################################################

declare -A species_group_map
declare -A group_confidence
declare -A group_color

load_group() {
  local group="$1"
  local array_name="${group}_names[@]"

  for s in "${!array_name}"; do
    species_group_map["$s"]="$group"
  done

  group_color["$group"]=$(eval "echo \${${group}[color]}")
  group_confidence["$group"]=$(eval "echo \${${group}[confidence]}")
}

load_group woodpecker
load_group raptor
load_group owl
load_group songbird
load_group hummingbird
load_group duck

declare -A last_seen

############################################################
# MAIN LOOP
############################################################

tail -F "$LOG" | \
while read -r line; do

  species=$(echo "$line" | jq -r '.species')
  confidence=$(echo "$line" | jq -r '.confidence')

  if [[ -z "$species" || "$species" == "null" ]]; then
    continue
  fi

  now=$(date +%s)

  if $DEBUG; then
    echo "[DEBUG] Detected species: '$species' (confidence: $confidence)"
  fi

  # Skip null or missing confidence
  if [[ "$confidence" == "null" || -z "$confidence" ]]; then
    if $DEBUG; then
      echo "[DEBUG] Skipping due to null/missing confidence"
    fi
    continue
  fi

  # Convert string confidence ("0.42") to float
  confidence=$(printf "%f" "$confidence" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    if $DEBUG; then
      echo "[DEBUG] Confidence conversion failed — skipping"
    fi
    continue
  fi

  group="${species_group_map[$species]}"
  if [[ -z "$group" ]]; then
    continue
  fi

  if $DEBUG; then
    echo "[DEBUG] Species '$species' matched group '$group'"
  fi

  if [[ -n "${last_seen[$species]}" ]]; then
    elapsed=$((now - last_seen[$species]))
    if (( elapsed < COOLDOWN )); then
      if $DEBUG; then
        echo "[DEBUG] Cooldown active for '$species' ($elapsed < $COOLDOWN) — skipping"
      fi
      continue
    fi
  fi

  min_conf="${group_confidence[$group]}"
  conf_ok=$(awk -v c="$confidence" -v m="$min_conf" 'BEGIN {print (c >= m)}')

  if [[ "$conf_ok" -eq 0 ]]; then
    if $DEBUG; then
      echo "[DEBUG] Confidence too low ($confidence < $min_conf) — skipping"
    fi
    continue
  fi

  last_seen[$species]=$now

  embed_color="${group_color[$group]}"
  CONFIDENCE_PCT=$(awk -v c="$confidence" 'BEGIN {printf "%.1f", c*100}')

  json_payload=$(jq -n \
    --arg species "$species" \
    --arg LOCATION "$LOCATION" \
    --arg CONFIDENCE "$CONFIDENCE_PCT" \
    --argjson color "$embed_color" \
    '{
      content: ($species + " at " + $LOCATION),
      embeds: [
        {
          title: $species,
          fields: [
            { name: "Confidence", value: ($CONFIDENCE + "%"), inline: true }
          ],
          color: $color
        }
      ]
    }'
  )

  response=$(curl -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    "$WEBHOOK_URL")

  http_body=$(echo "$response" | sed '$d')
  http_code=$(echo "$response" | tail -n1)

  if [[ "$http_code" != "204" ]]; then
    echo "[DEBUG] Discord ERROR $http_code"
    echo "[DEBUG] Payload sent:"
    echo "$json_payload"
    echo "[DEBUG] Response body:"
    echo "$http_body"
  fi

done
