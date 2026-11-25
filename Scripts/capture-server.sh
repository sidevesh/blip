#!/bin/bash
# Screen capture helper for iterating on the banner's look from a shell that has no Screen
# Recording permission. Run it in a terminal that has the permission and leave it running:
#
#   ~/Projects/OSS/blip/Scripts/capture-server.sh
#
# It waits for request files in /tmp/blip-capture:
#
#   <name>.req containing   ours <blip arguments...>   shows a banner with the repo's build, captures it
#                           empty                       captures the corner with no banner
#                           native                      beeps and asks you to press a volume key
#
# and writes <name>.png (2x pixels) next to it. The arguments go to the blip binary only; nothing
# in a request is run through a shell. Ctrl+C stops it.
set -u
DIR=/tmp/blip-capture
BLIP="$HOME/Projects/OSS/blip/.build/release/blip"
mkdir -p "$DIR"
TMP=$(mktemp -d)
swiftc -O -o "$TMP/rect" "$(dirname "$0")/rect.swift" || exit 1
IFS=, read -r X Y W H < <("$TMP/rect")
# A bit more room on every side than the banner needs, and two more banner slots below (76 pt
# each), so the native banner and Blip's can be captured together.
RECT="$((X - 20)),$((Y > 6 ? Y - 6 : 0)),$((W + 40)),$((H + 12 + 152))"

capture() { screencapture -x -R"$RECT" "$DIR/$1.png" && echo "  saved $DIR/$1.png"; }

native() { # name
  afplay /System/Library/Sounds/Glass.aiff &
  echo ">>> Press a VOLUME key now (once) — capturing in 3 seconds…"
  sleep 3
  capture "$1"
  sleep 3
}

ours() { # name args...
  local name=$1; shift
  "$BLIP" "$@" --duration 4 --background
  sleep 1.5
  capture "$name"
  sleep 3.2
}

echo "Waiting for requests in $DIR (Ctrl+C to stop)."

while true; do
  for req in "$DIR"/*.req; do
    [ -e "$req" ] || continue
    name=$(basename "$req" .req)
    read -r -a words < "$req"
    rm -f "$req"
    echo "Request $name: ${words[*]:-}"
    case "${words[0]:-}" in
      ours) ours "$name" "${words[@]:1}" ;;
      empty) capture "$name" ;;
      native) native "$name" ;;
      *) echo "  unknown request" ;;
    esac
    : > "$DIR/$name.done"
  done
  sleep 0.5
done
