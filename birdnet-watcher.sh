#!/bin/bash
# ============================================================
# BirdNET-Go Watcher — Version 8
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
# Version 8:
#   - Updated for the multi-model BirdNET-Go (BirdNET, Perch, bat models)
#   - Only approved detections are processed; pending and
#     discarded detections in the log are ignored
#   - Added BAT group (purple), all bats in the USA East bat model
#   - Added FROG group (olive), region-appropriate frogs and toads
#   - Added MAMMAL group (brown)
#   - Added INSECT group (orange)
#   - Added optional per-group cooldown; groups without one use COOLDOWN
#   - Added alternate names where BirdNET-Go's name depends on the
#     English locale setting (some bats, treefrogs, insects, teal)
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
LOCATION="MoonLake"

COOLDOWN=60
DEBUG=true

############################################################
# GROUP DEFINITIONS (ALL LOWERCASE)
#
# [cooldown] is optional, in seconds. Groups without it use
# COOLDOWN. Frogs and insects call for hours at a time, so
# those groups get long cooldowns to keep Discord quiet.
#
# Names must match what BirdNET-Go logs. Some names depend on
# the English locale setting, so both forms are listed.
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
  "eastern bluebird"
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
  "green-winged teal"
  "eurasian/green-winged teal"
  "hooded merganser"
)

declare -A bat=(
  [color]=8388736
  [confidence]=0.20
  [cooldown]=300
)
bat_names=(
  "big brown bat"
  "silver-haired bat"
  "eastern red bat"
  "northern hoary bat"
  "hoary bat"
  "northern yellow bat"
  "seminole bat"
  "southeastern myotis"
  "gray bat"
  "myotis grisescens"
  "eastern small-footed myotis"
  "myotis leibii"
  "little brown bat"
  "myotis lucifugus"
  "northern myotis"
  "myotis septentrionalis"
  "indiana bat"
  "myotis sodalis"
  "evening bat"
  "nycticeius humeralis"
  "tricolored bat"
  "perimyotis subflavus"
  "mexican free-tailed bat"
  "tadarida brasiliensis"
  "townsend's big-eared bat"
)

declare -A frog=(
  [color]=7048739
  [confidence]=0.50
  [cooldown]=1800
)
frog_names=(
  "american toad"
  "fowler's toad"
  "southern toad"
  "oak toad"
  "eastern narrow-mouthed toad"
  "eastern spadefoot"
  "northern cricket frog"
  "southern cricket frog"
  "spring peeper"
  "upland chorus frog"
  "southern chorus frog"
  "ornate chorus frog"
  "bird-voiced treefrog"
  "green treefrog"
  "gray treefrog"
  "cope's gray tree frog"
  "cope's gray treefrog"
  "pine woods tree frog"
  "pine woods treefrog"
  "barking tree frog"
  "barking treefrog"
  "squirrel tree frog"
  "squirrel treefrog"
  "american bullfrog"
  "green frog"
  "pickerel frog"
  "southern leopard frog"
)

declare -A mammal=(
  [color]=9127187
  [confidence]=0.50
  [cooldown]=1800
)
mammal_names=(
  "coyote"
  "white-tailed deer"
  "eastern gray squirrel"
  "eastern chipmunk"
)

declare -A insect=(
  [color]=16747520
  [confidence]=0.80
  [cooldown]=3600
)
insect_names=(
  "common true katydid"
  "greater anglewing"
  "greater angle-wing"
  "oblong-winged katydid"
  "fork-tailed bush katydid"
  "sword-bearing conehead"
  "round-tipped conehead"
  "handsome meadow katydid"
  "southeastern field cricket"
  "southern wood cricket"
  "carolina ground cricket"
  "narrow-winged tree cricket"
  "red-headed bush cricket"
  "handsome trig"
  "say's trig"
  "columbian trig"
)

############################################################
# INTERNAL SETUP
############################################################

declare -A species_group_map
declare -A group_confidence
declare -A group_color
declare -A group_cooldown

load_group() {
  local group="$1"
  local array_name="${group}_names[@]"

  for s in "${!array_name}"; do
    species_group_map["$s"]="$group"
  done

  group_color["$group"]=$(eval "echo \${${group}[color]}")
  group_confidence["$group"]=$(eval "echo \${${group}[confidence]}")
  group_cooldown["$group"]=$(eval "echo \${${group}[cooldown]}")
}

load_group woodpecker
load_group raptor
load_group owl
load_group songbird
load_group hummingbird
load_group duck
load_group bat
load_group frog
load_group mammal
load_group insect

declare -A last_seen

############################################################
# MAIN LOOP
############################################################

tail -F "$LOG" | \
while read -r line; do

  # Only approved detections. The log also carries pending,
  # flushed and discarded detections for the same species.
  if [[ "$line" != *'"operation":"approve_detection"'* ]]; then
    continue
  fi

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

  cooldown="${group_cooldown[$group]:-$COOLDOWN}"

  if [[ -n "${last_seen[$species]}" ]]; then
    elapsed=$((now - last_seen[$species]))
    if (( elapsed < cooldown )); then
      if $DEBUG; then
        echo "[DEBUG] Cooldown active for '$species' ($elapsed < $cooldown) — skipping"
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
      content: ($species + " " + $CONFIDENCE + " at " + $LOCATION),
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
