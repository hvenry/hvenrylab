#!/usr/bin/env bash
# Clean shutdown on low battery; the battery is this server's UPS. See docs/powerguard.md.
# Before this, an outage drained it and power cut mid-write with ~14 SQLite DBs open.
# Runs as root from a systemd timer.

set -uo pipefail

THRESHOLD="${POWERGUARD_THRESHOLD:-15}"   # percent at which to shut down
WARN_AT="${POWERGUARD_WARN_AT:-40}"       # percent for a second warning
PROJECT_DIR="${POWERGUARD_PROJECT_DIR:-/home/hvenry/homelab}"
AC="/sys/class/power_supply/AC0/online"
BAT="/sys/class/power_supply/BAT0"
STATE="/run/homelab-powerguard.state"     # tmpfs: cleared on every boot

log() { logger -t homelab-powerguard "$*"; echo "$*"; }

# Never source .env: it is Compose syntax, and sourcing executes whatever is in it.
topic() { sed -n 's/^NTFY_TOPIC=//p' "$PROJECT_DIR/.env" 2>/dev/null | head -1; }

notify() { # notify <title> <tags> <priority> <message>
  local t; t="$(topic)"
  [ -n "$t" ] || return 0
  curl -fsS --max-time 10 \
    -H "Title: $1" -H "Tags: $2" -H "Priority: $3" \
    -d "$4" "http://127.0.0.1:8082/$t" >/dev/null 2>&1 \
    || log "ntfy publish failed (continuing)"
}

[ -r "$AC" ] || { log "no $AC; is this the right machine?"; exit 0; }

on_ac="$(cat "$AC")"
capacity="$(cat "$BAT/capacity" 2>/dev/null || echo 100)"
seen="$(cat "$STATE" 2>/dev/null || echo none)"

# --- On mains -------------------------------------------------------------
# Keyed on AC online, NOT BAT0/status: with the Razer charge limit, status reads
# "Not charging" while plugged in, which would shut down a healthy machine.
if [ "$on_ac" = "1" ]; then
  if [ "$seen" != "none" ]; then
    notify "Mains power restored" "electric_plug" "3" \
      "Back on AC at ${capacity}%. No shutdown needed."
    log "AC restored at ${capacity}%"
    rm -f "$STATE"
  fi
  exit 0
fi

# --- On battery -----------------------------------------------------------
if [ "$seen" = "none" ]; then
  notify "Running on battery" "warning" "4" \
    "Mains power lost. Battery at ${capacity}%. Shutting down cleanly at ${THRESHOLD}%."
  log "on battery at ${capacity}%"
  echo "onbattery" > "$STATE"
  seen="onbattery"
fi

if [ "$capacity" -le "$WARN_AT" ] && [ "$seen" = "onbattery" ]; then
  notify "Battery at ${capacity}%" "warning" "4" \
    "Still on battery. Clean shutdown at ${THRESHOLD}%."
  log "warn at ${capacity}%"
  echo "warned" > "$STATE"
fi

if [ "$capacity" -le "$THRESHOLD" ]; then
  [ "$seen" = "shutdown" ] && exit 0        # already in progress
  echo "shutdown" > "$STATE"

  notify "Shutting down" "electric_plug" "5" \
    "Battery ${capacity}%. Stopping containers and powering off."
  log "threshold reached at ${capacity}%; stopping stack"

  # SIGTERM so databases close cleanly; bounded so a stuck container can't block poweroff.
  timeout 120 docker compose --project-directory "$PROJECT_DIR" down \
    >/dev/null 2>&1 || log "compose down did not finish cleanly; powering off anyway"

  sync
  log "powering off"
  systemctl poweroff
fi
