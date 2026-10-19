#!/usr/bin/env bats
# capslock_control: false keeps Caps Lock as Caps Lock: no LaunchAgent, no
# visual-script remap, and the live mapping is cleared on apply.

load test_helper

TMPL="$BATS_TEST_DIRNAME/../.chezmoiscripts/run_onchange_launchagents.sh.tmpl"

setup() {
  TEST_DIR="$(mktemp -d)"
  mkdir -p "$TEST_DIR/bin"
  export HIDUTIL_LOG="$TEST_DIR/hidutil.log"
  export HIDUTIL_MAPPING=""
  cat > "$TEST_DIR/bin/hidutil" <<'EOF'
#!/bin/bash
echo "$*" >> "$HIDUTIL_LOG"
[ "$2" = "--get" ] && printf '%s\n' "$HIDUTIL_MAPPING"
exit 0
EOF
  chmod +x "$TEST_DIR/bin/hidutil"
  PATH="$TEST_DIR/bin:$PATH"
  eval "$(sed -n '/^should_skip_agent() {/,/^}/p' "$TMPL")"
  eval "$(sed -n '/^capslock_clear_live_mapping() {/,/^}/p' "$TMPL")"
}

teardown() {
  rm -rf "$TEST_DIR"
}

CAPS_ONLY='(
    {
    HIDKeyboardModifierMappingDst = 30064771296;
    HIDKeyboardModifierMappingSrc = 30064771129;
}
)'

@test "capslock_control=false skips the capslock-control LaunchAgent" {
  CAPSLOCK_CONTROL=false
  should_skip_agent capslock-control
}

@test "capslock_control=true or unset keeps the capslock-control LaunchAgent" {
  CAPSLOCK_CONTROL=true
  ! should_skip_agent capslock-control
  unset CAPSLOCK_CONTROL
  ! should_skip_agent capslock-control
}

@test "capslock_control=false clears a live Caps Lock → Control mapping" {
  CAPSLOCK_CONTROL=false HIDUTIL_MAPPING="$CAPS_ONLY"
  run capslock_clear_live_mapping
  [ "$status" -eq 0 ]
  grep -q 'UserKeyMapping":\[\]' "$HIDUTIL_LOG"
}

@test "capslock_control=false leaves other remaps alone and warns" {
  CAPSLOCK_CONTROL=false
  HIDUTIL_MAPPING='({HIDKeyboardModifierMappingDst=30064771296;HIDKeyboardModifierMappingSrc=30064771129;},{HIDKeyboardModifierMappingDst=30064771113;HIDKeyboardModifierMappingSrc=30064771300;})'
  run capslock_clear_live_mapping
  [[ "$output" == *"other key remaps are active"* ]]
  ! grep -q -- '--set' "$HIDUTIL_LOG"
}

@test "capslock_control=true never touches the live mapping" {
  CAPSLOCK_CONTROL=true HIDUTIL_MAPPING="$CAPS_ONLY"
  run capslock_clear_live_mapping
  [ ! -s "$HIDUTIL_LOG" ]
}

@test "macos-visual.sh remaps Caps Lock only when capslock_control is not false" {
  run grep -B2 'HIDKeyboardModifierMappingSrc' "$BATS_TEST_DIRNAME/../macos-visual.sh"
  [[ "$output" == *'DOTFILES_CAPSLOCK_CONTROL:-true}" != "false"'* ]]
  grep -q 'DOTFILES_CAPSLOCK_CONTROL="{{ dig "capslock_control" (dig "owner_machine" false .) . }}"' \
    "$BATS_TEST_DIRNAME/../.chezmoiscripts/run_onchange_macos.sh.tmpl"
}

@test "chezmoi config keeps capslock_control across chezmoi init" {
  grep -q 'hasKey . "capslock_control"' "$BATS_TEST_DIRNAME/../.chezmoi.yaml.tmpl"
  grep -q '^  capslock_control: {{ \$capslockControl }}' "$BATS_TEST_DIRNAME/../.chezmoi.yaml.tmpl"
}

@test "capslock_control defaults to owner_machine, so a new user keeps Caps Lock" {
  grep -q '\$capslockControl := \$ownerMachine' "$BATS_TEST_DIRNAME/../.chezmoi.yaml.tmpl"
  grep -q 'CAPSLOCK_CONTROL="{{ dig "capslock_control" (dig "owner_machine" false .) . }}"' "$TMPL"
}
