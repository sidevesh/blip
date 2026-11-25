#!/bin/sh
# Captures every banner over your own wallpaper and builds Docs/banners-<mode>.png (a few) and
# Docs/all-<mode>.png (every preset). It reads the current appearance (dark or light) itself and
# changes nothing on your system. Keep the top-right corner of the screen free of windows.
# Needs Screen Recording permission for the terminal, and `pip install pillow`.
set -e
cd "$(dirname "$0")/.."
swift build -c release --product blip >/dev/null
BLIP=.build/release/blip
MODE=light
defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark && MODE=dark
OUT=$(mktemp -d)
swiftc -O -o "$OUT/rect" Scripts/rect.swift
IFS=, read -r X Y W H <<EOF
$("$OUT/rect")
EOF
# 20 pt either side of the banner area and 6 pt above it, which Scripts/gallery.py crops from.
RECT="$((X - 20)),$((Y > 6 ? Y - 6 : 0)),$((W + 40)),$((H + 12))"
echo "Capturing in $MODE mode…"

shot() { # name preset args...
  name=$1; shift
  "$BLIP" "$@" --duration 4 --background
  sleep 1.5
  screencapture -x -R"$RECT" "$OUT/$name.png"
  sleep 3.2
}

shot 01-volume volume --level 0.62
shot 02-mute mute
shot 03-sound-output sound-output --title AirPods --level 0.35 --icon airpods-pro
shot 04-brightness brightness --level 0.74
shot 05-keyboard keyboard-brightness --level 0.5
shot 06-contrast contrast --level 0.5
shot 07-microphone microphone
shot 08-microphone-muted microphone-muted
shot 09-all-microphones all-microphones --muted
shot 10-low-battery low-battery
shot 11-charging charging --time-until-full 1:20
shot 12-low-power low-power
shot 13-battery battery --percent 80 --charging
shot 14-accessory accessory --title AirPods --percent 80 --icon airpods-pro
shot 15-listening listening-mode
shot 16-focus focus --title Work
shot 17-camera camera --off
shot 18-caps-lock caps-lock
shot 19-wifi wifi --off
shot 20-bluetooth bluetooth
shot 21-airplane airplane-mode
shot 22-notifications notifications --off
shot 23-screen-lock screen-lock
shot 24-play play
shot 25-pause pause
shot 26-play-pause play-pause
shot 27-next next
shot 28-previous previous
shot 29-dpi dpi --value 1600
shot 30-pointer pointer-speed --level 0.6
shot 31-scroll-speed scroll-speed --level 0.5
shot 32-smart-shift smart-shift
shot 33-easy-switch easy-switch --value 2
shot 34-scroll-direction scroll-direction
shot 35-success success --title Saved
shot 36-error error --title Failed
shot 37-warning warning
shot 38-info info
shot 39-screenshot screenshot
shot 40-clipboard clipboard
shot 41-slider slider --title Fan --icon sf:fan --trailing-icon sf:fan.fill --level 0.4
shot 42-message message --title Blip --message Hello --icon sf:sparkles

mkdir -p Docs
python3 Scripts/gallery.py "$OUT" Docs "$MODE"
