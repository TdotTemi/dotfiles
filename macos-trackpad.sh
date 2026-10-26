#!/bin/bash
# Trackpad swipe gestures: 3 or 4 fingers (chezmoi data trackpad_swipe_fingers).
# 3 turns three-finger drag off (macOS cannot use 3 fingers for both) and
# moves swipes between desktops and Mission Control to 3 fingers. 4-finger
# swipes stay on too, which is the macOS default when three-finger drag is off.
# 4 (default) writes nothing, unless this script set 3 before: then it puts
# back the stock gestures (3-finger swipes off, 4-finger swipes on), so the
# opt-out is reversible. Keys listed in ~/.config/dotfiles/macos-defaults-skip
# (DOTFILES_MACOS_DEFAULTS_SKIP) are left alone.
# Runs on every profile, after macos-visual.sh, so it wins over the full
# profile's three-finger drag default.

set -euo pipefail

fingers="${DOTFILES_TRACKPAD_SWIPE_FINGERS:-4}"
marker="${DOTFILES_TRACKPAD_MARKER:-$HOME/.local/state/dotfiles/trackpad-swipe-3}"
skip_file="${DOTFILES_MACOS_DEFAULTS_SKIP:-$HOME/.config/dotfiles/macos-defaults-skip}"

case "$fingers" in
  3) drag=false; three=2 ;;
  4)
    [ -e "$marker" ] || exit 0
    drag=""; three=0 ;;
  *)
    echo "⚠ trackpad_swipe_fingers must be 3 or 4 (got: $fingers); trackpad left alone" >&2
    exit 0 ;;
esac

skipped() {
  [ -r "$skip_file" ] || return 1
  sed 's/#.*//' "$skip_file" | awk -v d="$1" -v k="$2" '$1 == d { $1 = ""; sub(/^ +/, ""); sub(/ +$/, ""); if ($0 == k) found = 1 } END { exit !found }'
}

write() {
  skipped "$1" "$2" || defaults write "$@"
}

for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  [ -z "$drag" ] || write "$domain" TrackpadThreeFingerDrag -bool "$drag"
  write "$domain" TrackpadThreeFingerHorizSwipeGesture -int "$three"
  write "$domain" TrackpadThreeFingerVertSwipeGesture -int "$three"
  write "$domain" TrackpadFourFingerHorizSwipeGesture -int 2
  write "$domain" TrackpadFourFingerVertSwipeGesture -int 2
done

if [ "$fingers" = "3" ]; then
  mkdir -p "$(dirname "$marker")" && : > "$marker"
else
  rm -f "$marker"
fi

# Apply the new gestures now, without a logout.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
killall Dock 2>/dev/null || true
if [ "$fingers" = "3" ]; then
  echo "✓ Trackpad swipes use 3 fingers (three-finger drag off). Log out and in if 3 fingers still do nothing."
else
  echo "✓ Trackpad swipes back on 4 fingers (stock gestures)."
fi
