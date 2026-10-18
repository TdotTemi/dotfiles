#!/bin/bash
# Pin Claude Code's default model and permission mode in ~/.claude/settings.json.
#
# Per AGENTS.md § Model Configuration, Claude Code's tier-1 default is
# "Claude Opus 5.5 XHigh" — which Claude Code expresses as:
#   - model:       "claude-opus-5-5"   (rejects effort suffixes such as -max)
#   - effortLevel: "xhigh"             (persistable: low/medium/high/xhigh; max is in-session only)
#
# Keep these values equal to defaultModel/defaultEffort in Agentfile.yaml.
# One machine or an org overlay can pick another pair without editing this
# file: see the override block below.
# agentbrew writes the same keys; this pin covers machines where agentbrew
# cannot run (tests/claude-model-agentfile-consistency.bats).
#
# ~/.claude/settings.json is owned by Claude Code itself — it writes hooks,
# MCPs, plugins, etc. into the same file. We use `jq` to merge in just the
# model/permission keys, preserving every other field. Runs after every chezmoi
# apply. Idempotent.
#
# The ~/bin/claude wrapper installed by run_after_claude-wrapper.sh strips
# ANTHROPIC_MODEL env leaks (different concern); this script is the
# config-file source of truth for which model Claude Code launches with.
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd 2>/dev/null || true)"
if [ -f "$_script_dir/lib/dotfiles-endpoint-paths.sh" ]; then
  # shellcheck source=../lib/dotfiles-endpoint-paths.sh
  source "$_script_dir/lib/dotfiles-endpoint-paths.sh"
  dotfiles_prepend_endpoint_tool_paths "$_script_dir/bin"
fi
unset _script_dir

SETTINGS="$HOME/.claude/settings.json"
DESIRED_MODEL="claude-opus-5-5"
DESIRED_EFFORT="xhigh"
DESIRED_PERMISSION_MODE="bypassPermissions"

# Per-machine override. Env wins over chezmoi data, key by key; an unset key
# keeps the base default above.
#   env:          DOTFILES_CLAUDE_MODEL, DOTFILES_CLAUDE_EFFORT, DOTFILES_CLAUDE_PERMISSIONS
#   chezmoi data: claude_model, claude_effort, claude_permissions (~/.config/chezmoi/chezmoi.yaml)
# claude_permissions: manage (default) pins bypassPermissions and grants every
# MCP server; keep leaves the person's permission settings and prompts alone.
_data_model=""
_data_effort=""
_data_permissions=""
if { [ -z "${DOTFILES_CLAUDE_MODEL:-}" ] || [ -z "${DOTFILES_CLAUDE_EFFORT:-}" ] || [ -z "${DOTFILES_CLAUDE_PERMISSIONS:-}" ]; } \
  && command -v chezmoi >/dev/null 2>&1; then
  IFS='|' read -r _data_model _data_effort _data_permissions < <(
    chezmoi execute-template '{{ dig "claude_model" "" . }}|{{ dig "claude_effort" "" . }}|{{ dig "claude_permissions" "" . }}' 2>/dev/null || true
  ) || true
fi
PERMISSIONS_MODE="${DOTFILES_CLAUDE_PERMISSIONS:-${_data_permissions:-manage}}"
case "$PERMISSIONS_MODE" in
  manage|keep) ;;
  *) echo "⚠ claude_permissions '$PERMISSIONS_MODE' is not manage or keep — using manage" >&2; PERMISSIONS_MODE="manage" ;;
esac
unset _data_permissions
DESIRED_MODEL="${DOTFILES_CLAUDE_MODEL:-${_data_model:-$DESIRED_MODEL}}"
_effort="${DOTFILES_CLAUDE_EFFORT:-${_data_effort:-$DESIRED_EFFORT}}"
# Only the keys this Mac overrides (lib/claude-model-layer.sh); empty = unset.
_override_model="${DOTFILES_CLAUDE_MODEL:-${_data_model:-}}"
_override_effort=""
case "$_effort" in
  low|medium|high|xhigh)
    DESIRED_EFFORT="$_effort"
    _override_effort="${DOTFILES_CLAUDE_EFFORT:-${_data_effort:-}}" ;;
  *) echo "⚠ Claude effort '$_effort' is not persistable (low/medium/high/xhigh) — keeping $DESIRED_EFFORT" >&2 ;;
esac
unset _data_model _data_effort _effort

# modules/claude/doctor.sh reads the resolved pair here, so check and fix agree.
if [ "${1:-}" = "--print-desired" ]; then
  printf '%s %s\n' "$DESIRED_MODEL" "$DESIRED_EFFORT"
  exit 0
fi
# The ~/bin/claude wrapper and the doctor read the permission mode here too.
if [ "${1:-}" = "--print-permissions" ]; then
  printf '%s\n' "$PERMISSIONS_MODE"
  exit 0
fi
if [ "${1:-}" = "--print-override" ]; then
  printf '%s|%s\n' "$_override_model" "$_override_effort"
  exit 0
fi
unset _override_model _override_effort

# Skip if Claude Code isn't installed (no ~/.local/bin/claude binary).
[ -e "$HOME/.local/bin/claude" ] || exit 0

# Skip if jq isn't available — better to no-op than to corrupt the file.
command -v jq >/dev/null 2>&1 || {
  echo "✗ jq missing — cannot safely merge ~/.claude/settings.json (install jq via Brewfile)"
  exit 0
}

mkdir -p "$HOME/.claude"

# Read current state, defaulting to {} if file missing/empty.
if [ -s "$SETTINGS" ]; then
  CURRENT="$(cat "$SETTINGS")"
else
  CURRENT="{}"
fi

_sync_claude_mcp_permissions() {
  [ "$PERMISSIONS_MODE" = "keep" ] && return 0
  local claude_json="$HOME/.claude.json"
  [ -f "$claude_json" ] || return 0
  local perm_tmp merged current_allow
  current_allow="$(jq -c '.permissions.allow // []' "$SETTINGS")"
  merged="$(jq -c --slurpfile cj "$claude_json" '
    ($cj[0].mcpServers // {}) as $servers |
    ($servers | keys | map("mcp__" + . + "__*")) as $desired |
    (.permissions.allow // [] | map(select(test("^mcp__") | not))) as $non_mcp |
    ($desired + $non_mcp | unique) as $merged |
    $merged
  ' "$SETTINGS")"
  [ "$current_allow" = "$merged" ] && return 0
  perm_tmp="$(mktemp)"
  jq --slurpfile cj "$claude_json" '
    ($cj[0].mcpServers // {}) as $servers |
    ($servers | keys | map("mcp__" + . + "__*")) as $desired |
    (.permissions.allow // [] | map(select(test("^mcp__") | not))) as $non_mcp |
    ($desired + $non_mcp | unique) as $merged |
    .permissions = ((.permissions // {}) + {allow: $merged})
  ' "$SETTINGS" > "$perm_tmp"
  jq -e . "$perm_tmp" >/dev/null 2>&1 || {
    echo "✗ jq produced invalid JSON — refusing to merge MCP permissions into $SETTINGS"
    rm -f "$perm_tmp"
    exit 1
  }
  mv "$perm_tmp" "$SETTINGS"
  echo "✓ Claude Code MCP permission grants synced from ~/.claude.json"
}

# Check if model pin already correct — skip model write but still sync MCP grants.
CURRENT_MODEL="$(printf '%s' "$CURRENT" | jq -r '.model // ""')"
CURRENT_EFFORT="$(printf '%s' "$CURRENT" | jq -r '.effortLevel // ""')"
CURRENT_PERMISSION_MODE="$(printf '%s' "$CURRENT" | jq -r '.permissions.defaultMode // ""')"
CURRENT_SKIP_AUTO_PROMPT="$(printf '%s' "$CURRENT" | jq -r '.skipAutoPermissionPrompt // false')"
_permissions_current=1
if [ "$PERMISSIONS_MODE" = "manage" ] \
  && { [ "$CURRENT_PERMISSION_MODE" != "$DESIRED_PERMISSION_MODE" ] || [ "$CURRENT_SKIP_AUTO_PROMPT" != "true" ]; }; then
  _permissions_current=0
fi
if [ "$CURRENT_MODEL" = "$DESIRED_MODEL" ] \
  && [ "$CURRENT_EFFORT" = "$DESIRED_EFFORT" ] \
  && [ "$_permissions_current" = "1" ]; then
  _sync_claude_mcp_permissions
  exit 0
fi

# Merge: set model and permission defaults, preserve everything else.
# `--arg` for safe string interpolation. Atomic write via tmp file.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
if [ "$PERMISSIONS_MODE" = "keep" ]; then
  printf '%s' "$CURRENT" \
    | jq --arg model "$DESIRED_MODEL" --arg effort "$DESIRED_EFFORT" '.model = $model | .effortLevel = $effort' \
    > "$TMP"
else
  printf '%s' "$CURRENT" \
    | jq --arg model "$DESIRED_MODEL" --arg effort "$DESIRED_EFFORT" --arg permissionMode "$DESIRED_PERMISSION_MODE" \
         '.model = $model | .effortLevel = $effort | .permissions.defaultMode = $permissionMode | .skipAutoPermissionPrompt = true' \
    > "$TMP"
fi

# Sanity-check the result parses as JSON before installing.
jq -e . "$TMP" >/dev/null 2>&1 || {
  echo "✗ jq produced invalid JSON — refusing to overwrite $SETTINGS"
  exit 1
}

mv "$TMP" "$SETTINGS"
if [ "$PERMISSIONS_MODE" = "keep" ]; then
  echo "✓ Claude Code settings.json pinned: model=$DESIRED_MODEL, effortLevel=$DESIRED_EFFORT (permissions kept)"
else
  echo "✓ Claude Code settings.json pinned: model=$DESIRED_MODEL, effortLevel=$DESIRED_EFFORT, permissionMode=$DESIRED_PERMISSION_MODE"
fi

_sync_claude_mcp_permissions
