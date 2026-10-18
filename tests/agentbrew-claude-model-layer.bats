#!/usr/bin/env bats
# run_after_agentbrew-sync.sh merges this Mac's Claude model/effort override
# last, so agentbrew's model sync and the dotfiles pin agree.

load test_helper

setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR/home"
  export DOTFILES_DIR="$TEST_DIR/dotfiles"
  mkdir -p "$HOME" "$DOTFILES_DIR/.chezmoiscripts"
  cp "$BATS_TEST_DIRNAME/../.chezmoiscripts/run_after_claude-settings-model.sh" "$DOTFILES_DIR/.chezmoiscripts/"
  unset DOTFILES_CLAUDE_MODEL DOTFILES_CLAUDE_EFFORT DOTFILES_CLAUDE_PERMISSIONS
  source "$BATS_TEST_DIRNAME/../lib/claude-model-layer.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "claude model layer: carries this Mac's effort override" {
  DOTFILES_CLAUDE_EFFORT=medium claude_model_layer_write "$TEST_DIR/layer.yaml"
  grep -qx 'defaultModel: claude-opus-5-5' "$TEST_DIR/layer.yaml"
  grep -qx 'defaultEffort: medium' "$TEST_DIR/layer.yaml"
}

@test "claude model layer: matches the Agentfile default when nothing is overridden" {
  claude_model_layer_write "$TEST_DIR/layer.yaml"
  base_model="$(sed -n 's/^defaultModel: //p' "$BATS_TEST_DIRNAME/../Agentfile.yaml")"
  base_effort="$(sed -n 's/^defaultEffort: //p' "$BATS_TEST_DIRNAME/../Agentfile.yaml")"
  grep -qx "defaultModel: $base_model" "$TEST_DIR/layer.yaml"
  grep -qx "defaultEffort: $base_effort" "$TEST_DIR/layer.yaml"
}

@test "claude model layer: the sync script merges it after the other Agentfiles" {
  run grep -n 'AGENTFILE_PATHS+=("$CLAUDE_MODEL_LAYER")' "$BATS_TEST_DIRNAME/../.chezmoiscripts/run_after_agentbrew-sync.sh"
  [ "$status" -eq 0 ]
  layer_line="${output%%:*}"
  merge_line="$(grep -n 'agentfile merge "\${AGENTFILE_PATHS\[@\]}"' "$BATS_TEST_DIRNAME/../.chezmoiscripts/run_after_agentbrew-sync.sh" | cut -d: -f1)"
  [ "$layer_line" -lt "$merge_line" ]
}
