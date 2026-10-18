#!/usr/bin/env bats
# use_local_ai=false must keep the local-AI stack off: no LaunchAgents and no
# doctor fixes (which would curl | bash the opencode installer).

load test_helper

_load_launchagent_gate() {
  local tmpl="$BATS_TEST_DIRNAME/../.chezmoiscripts/run_onchange_launchagents.sh.tmpl"
  PROFILE=core USE_CURSOR=false USE_LOCAL_AI="$1"
  eval "$(sed -n '/^should_skip_agent() {/,/^}/p' "$tmpl")"
}

@test "LaunchAgent gate: use_local_ai=false skips ollama, opencode-serve and local-ai-warmup" {
  _load_launchagent_gate false
  should_skip_agent ollama
  should_skip_agent opencode-serve
  should_skip_agent local-ai-warmup
}

@test "LaunchAgent gate: use_local_ai=true keeps the local-AI agents" {
  _load_launchagent_gate true
  ! should_skip_agent ollama
  ! should_skip_agent opencode-serve
  ! should_skip_agent local-ai-warmup
}

@test "local-ai doctor module runs no checks when use_local_ai=false" {
  calls=0
  check() { calls=$((calls + 1)); }
  check_advisory() { calls=$((calls + 1)); }
  USE_LOCAL_AI=false
  source "$BATS_TEST_DIRNAME/../modules/local-ai/doctor.sh"
  [ "$calls" -eq 0 ]
}

@test "local-ai doctor module runs its checks when use_local_ai=true" {
  calls=0
  check() { calls=$((calls + 1)); }
  check_advisory() { calls=$((calls + 1)); }
  USE_LOCAL_AI=true
  source "$BATS_TEST_DIRNAME/../modules/local-ai/doctor.sh"
  [ "$calls" -gt 0 ]
}
