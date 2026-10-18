#!/bin/bash
# Install a ~/bin/claude wrapper that strips ANTHROPIC_MODEL before exec.
#
# WHY ~/bin/ instead of ~/.local/bin/:
#   claude update overwrites ~/.local/bin/claude with a new symlink on every update,
#   which would destroy a wrapper placed there. ~/bin/ comes before ~/.local/bin/ in
#   PATH (set by zshrc) so this wrapper takes precedence and survives updates.
#
# The wrapper defensively strips leaked ANTHROPIC_MODEL values so Claude Code
# uses its own configured model selection.
# Runs after every chezmoi apply. Idempotent.
set -euo pipefail

WRAPPER="$HOME/bin/claude"
REAL_CLAUDE="$HOME/.local/bin/claude"

# Skip if claude isn't installed
if [ ! -e "$REAL_CLAUDE" ]; then
  exit 0
fi

# Ensure ~/bin exists
mkdir -p "$HOME/bin"

# claude_permissions: keep → the wrapper adds no --permission-mode.
# chezmoi runs scripts from a temp copy, so find the pin script in the source dir.
_pin_script="${CHEZMOI_SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.chezmoiscripts/run_after_claude-settings-model.sh"
PERMISSIONS_MODE="$(bash "$_pin_script" --print-permissions 2>/dev/null || true)"
[ "$PERMISSIONS_MODE" = "keep" ] || PERMISSIONS_MODE="manage"

# Skip if wrapper is already correct
if [ -f "$WRAPPER" ] \
  && grep -q "unset ANTHROPIC_MODEL" "$WRAPPER" 2>/dev/null \
  && grep -q "default-name-from-cwd" "$WRAPPER" 2>/dev/null \
  && grep -q "default-permission-mode-bypass" "$WRAPPER" 2>/dev/null \
  && grep -q "remote-control-flags-after-verb" "$WRAPPER" 2>/dev/null \
  && grep -q "Tag: permissions-mode=$PERMISSIONS_MODE\$" "$WRAPPER" 2>/dev/null \
  && ! grep -q "inaccessible on Enterprise accounts" "$WRAPPER" 2>/dev/null; then
  exit 0
fi

cat > "$WRAPPER" << 'WRAPPER_EOF'
#!/bin/bash
# claude wrapper — strips ANTHROPIC_MODEL so Claude Code uses its own model
# selection, defaults --permission-mode to bypassPermissions, and defaults
# --name to "[<folder-basename>]" so the cwd shows in the terminal title (per
# `claude --help`: "shown in the prompt box, /resume picker, and terminal title").
#
# Lives in ~/bin/ (before ~/.local/bin in PATH) so claude update cannot
# overwrite it. Managed by dotfiles — do not edit directly.

REAL_CLAUDE="$HOME/.local/bin/claude"

unset ANTHROPIC_MODEL

# claude_permissions from dotfiles (manage adds bypassPermissions; keep adds nothing).
# Tag: permissions-mode=@@PERMISSIONS_MODE@@
_permissions_mode="@@PERMISSIONS_MODE@@"

# Remote Control refuses to start when --permission-mode comes before the
# verb, so put the default after it. Reattaching (-c, --continue,
# --session-id) keeps the session's own mode, so add nothing then.
# Tag: remote-control-flags-after-verb
case "${1:-}" in
  rc|remote-control)
    _verb="$1"
    shift
    for _arg in "$@"; do
      case "$_arg" in
        --permission-mode|--permission-mode=*|-c|--continue|--session-id|--session-id=*)
          exec "$REAL_CLAUDE" "$_verb" "$@"
          ;;
      esac
    done
    [ "$_permissions_mode" = "keep" ] && exec "$REAL_CLAUDE" "$_verb" "$@"
    exec "$REAL_CLAUDE" "$_verb" --permission-mode bypassPermissions "$@"
    ;;
esac

_has_permission_mode=0
for _arg in "$@"; do
  case "$_arg" in
    --permission-mode|--permission-mode=*|--dangerously-skip-permissions)
      _has_permission_mode=1
      break
      ;;
  esac
done
if [ "$_has_permission_mode" = "0" ] && [ "$_permissions_mode" != "keep" ]; then
  set -- --permission-mode bypassPermissions "$@"
fi
# Tag: default-permission-mode-bypass

# Inject --name "[<folder>]" by default so the operator can see which folder
# each Ghostty tab is operating in. Skips when the user already provided -n
# or --name. Tag: default-name-from-cwd (used by the dotfiles installer to
# detect when this wrapper needs reinstalling). Source: 2026-05-27 operator
# directive — "shows on top which folder is devin or claude code is executing".
_has_name=0
for _arg in "$@"; do
  case "$_arg" in
    -n|--name) _has_name=1; break ;;
  esac
done
if [ "$_has_name" = "0" ]; then
  _folder="${PWD/#$HOME/~}"
  _basename="${_folder##*/}"
  set -- --name "[$_basename]" "$@"
fi

exec "$REAL_CLAUDE" "$@"
WRAPPER_EOF
sed -i.bak "s/@@PERMISSIONS_MODE@@/$PERMISSIONS_MODE/g" "$WRAPPER" && rm -f "$WRAPPER.bak"

chmod +x "$WRAPPER"
echo "✓ Claude wrapper installed at ~/bin/claude (strips ANTHROPIC_MODEL)"
