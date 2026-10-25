#!/bin/bash
# Trackpad swipe gestures: 3 or 4 fingers (chezmoi data trackpad_swipe_fingers).
# 4 (default) changes nothing: three-finger drag stays as the profile set it,
# and macOS keeps swipes between desktops and Mission Control on 4 fingers.
# 3 turns three-finger drag off (macOS cannot use 3 fingers for both) and
# moves those swipes to 3 fingers, as System Settings → Trackpad does.
# Runs on every profile, after macos-visual.sh, so it wins over the full
# profile's three-finger drag default.

set -euo pipefail

fingers="${DOTFILES_TRACKPAD_SWIPE_FINGERS:-4}"
[ "$fingers" = "3" ] || exit 0

for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  defaults write "$domain" TrackpadThreeFingerDrag -bool false
  defaults write "$domain" TrackpadThreeFingerHorizSwipeGesture -int 2
  defaults write "$domain" TrackpadThreeFingerVertSwipeGesture -int 2
  defaults write "$domain" TrackpadFourFingerHorizSwipeGesture -int 0
  defaults write "$domain" TrackpadFourFingerVertSwipeGesture -int 0
done

killall Dock 2>/dev/null || true
echo "✓ Trackpad swipes use 3 fingers (three-finger drag off). Log out and in if a gesture still needs 4."
