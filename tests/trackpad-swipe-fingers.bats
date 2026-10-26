#!/usr/bin/env bats
# trackpad_swipe_fingers: 3 moves swipes to 3 fingers and turns three-finger
# drag off; 4 (the default) writes nothing.

load test_helper

setup() {
  TEST_DIR="$(mktemp -d)"
  mkdir -p "$TEST_DIR/bin"
  export DEFAULTS_LOG="$TEST_DIR/defaults.log"
  printf '#!/bin/bash\necho "$*" >> "$DEFAULTS_LOG"\n' > "$TEST_DIR/bin/defaults"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_DIR/bin/killall"
  chmod +x "$TEST_DIR/bin/defaults" "$TEST_DIR/bin/killall"
  PATH="$TEST_DIR/bin:$PATH"
  SCRIPT="$BATS_TEST_DIRNAME/../macos-trackpad.sh"
  export DOTFILES_TRACKPAD_MARKER="$TEST_DIR/marker"
  export DOTFILES_MACOS_DEFAULTS_SKIP="$TEST_DIR/skip"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "trackpad_swipe_fingers=4 (default) writes no defaults" {
  run env -u DOTFILES_TRACKPAD_SWIPE_FINGERS bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -s "$DEFAULTS_LOG" ]
  DOTFILES_TRACKPAD_SWIPE_FINGERS=4 run bash "$SCRIPT"
  [ ! -s "$DEFAULTS_LOG" ]
}

@test "trackpad_swipe_fingers=3 turns drag off and turns on 3- and 4-finger swipes on both trackpads" {
  DOTFILES_TRACKPAD_SWIPE_FINGERS=3 run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  for d in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
    grep -qx "write $d TrackpadThreeFingerDrag -bool false" "$DEFAULTS_LOG"
    grep -qx "write $d TrackpadThreeFingerHorizSwipeGesture -int 2" "$DEFAULTS_LOG"
    grep -qx "write $d TrackpadThreeFingerVertSwipeGesture -int 2" "$DEFAULTS_LOG"
    grep -qx "write $d TrackpadFourFingerHorizSwipeGesture -int 2" "$DEFAULTS_LOG"
    grep -qx "write $d TrackpadFourFingerVertSwipeGesture -int 2" "$DEFAULTS_LOG"
  done
}

@test "macOS apply runs the trackpad script on every profile, after the visual script" {
  TMPL="$BATS_TEST_DIRNAME/../.chezmoiscripts/run_onchange_macos.sh.tmpl"
  grep -q 'DOTFILES_TRACKPAD_SWIPE_FINGERS="{{ dig "trackpad_swipe_fingers" 4 . }}" bash "{{ .chezmoi.sourceDir }}/macos-trackpad.sh"' "$TMPL"
  visual_line="$(grep -n 'macos-visual.sh"$' "$TMPL" | cut -d: -f1)"
  end_line="$(grep -n '^{{- end }}$' "$TMPL" | head -1 | cut -d: -f1)"
  trackpad_line="$(grep -n 'bash "{{ .chezmoi.sourceDir }}/macos-trackpad.sh"' "$TMPL" | cut -d: -f1)"
  [ "$trackpad_line" -gt "$visual_line" ]
  [ "$trackpad_line" -gt "$end_line" ]
  grep -q '# trackpad_swipe_fingers: {{ dig "trackpad_swipe_fingers" 4 . }}' "$TMPL"
}

@test "chezmoi config keeps trackpad_swipe_fingers across chezmoi init" {
  grep -q 'hasKey . "trackpad_swipe_fingers"' "$BATS_TEST_DIRNAME/../.chezmoi.yaml.tmpl"
  grep -q '^  trackpad_swipe_fingers: {{ \$trackpadSwipeFingers }}' "$BATS_TEST_DIRNAME/../.chezmoi.yaml.tmpl"
}

@test "doctor expects three-finger drag off when trackpad_swipe_fingers=3" {
  DOCTOR="$BATS_TEST_DIRNAME/../modules/macos/doctor.sh"
  grep -q 'if \[ "${TRACKPAD_SWIPE_FINGERS:-4}" = "3" \]; then' "$DOCTOR"
  grep -q 'TrackpadThreeFingerDrag "0" bool' "$DOCTOR"
  grep -q 'TRACKPAD_SWIPE_FINGERS=' "$BATS_TEST_DIRNAME/../bin/dotfiles-doctor"
}

@test "switching back from 3 to 4 restores the stock gestures and is then a no-op" {
  DOTFILES_TRACKPAD_SWIPE_FINGERS=3 run bash "$SCRIPT"
  [ -e "$DOTFILES_TRACKPAD_MARKER" ]
  : > "$DEFAULTS_LOG"
  DOTFILES_TRACKPAD_SWIPE_FINGERS=4 run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  for d in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
    grep -qx "write $d TrackpadThreeFingerHorizSwipeGesture -int 0" "$DEFAULTS_LOG"
    grep -qx "write $d TrackpadThreeFingerVertSwipeGesture -int 0" "$DEFAULTS_LOG"
    grep -qx "write $d TrackpadFourFingerHorizSwipeGesture -int 2" "$DEFAULTS_LOG"
  done
  ! grep -q TrackpadThreeFingerDrag "$DEFAULTS_LOG"
  [ ! -e "$DOTFILES_TRACKPAD_MARKER" ]
  : > "$DEFAULTS_LOG"
  DOTFILES_TRACKPAD_SWIPE_FINGERS=4 run bash "$SCRIPT"
  [ ! -s "$DEFAULTS_LOG" ]
}

@test "keys in macos-defaults-skip are left alone" {
  printf 'com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag  # mine\n' > "$DOTFILES_MACOS_DEFAULTS_SKIP"
  DOTFILES_TRACKPAD_SWIPE_FINGERS=3 run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q "write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag" "$DEFAULTS_LOG"
  grep -q "write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag" "$DEFAULTS_LOG"
}

@test "a value other than 3 or 4 warns and writes nothing" {
  DOTFILES_TRACKPAD_SWIPE_FINGERS=5 run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"must be 3 or 4"* ]]
  [ ! -s "$DEFAULTS_LOG" ]
}

@test "defaults preview expects three-finger drag off when trackpad_swipe_fingers=3" {
  grep -q 'TrackpadThreeFingerDrag" \] && \[ "$TRACKPAD_SWIPE_FINGERS" = "3" \]' "$BATS_TEST_DIRNAME/../bin/dotfiles-defaults-preview"
}
