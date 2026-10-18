#!/bin/bash
# This Mac's Claude model/effort as an Agentfile layer (defaultModel,
# defaultEffort), resolved by run_after_claude-settings-model.sh
# (claude_model / claude_effort chezmoi data, or DOTFILES_CLAUDE_*).
# run_after_agentbrew-sync.sh merges it last so agentbrew's model sync writes
# the same pair as the dotfiles pin; the agentbrew doctor module rebuilds the
# same merge to check the global Agentfile.

# claude_model_layer_write OUT — returns 1 when the pair cannot be resolved.
claude_model_layer_write() {
  local out="$1" pin="$DOTFILES_DIR/.chezmoiscripts/run_after_claude-settings-model.sh" model effort
  [ -f "$pin" ] || return 1
  read -r model effort < <(bash "$pin" --print-desired 2>/dev/null) || return 1
  [ -n "$model" ] && [ -n "$effort" ] || return 1
  printf 'defaultModel: %s\ndefaultEffort: %s\n' "$model" "$effort" > "$out"
}
