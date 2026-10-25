#!/usr/bin/env bats
# The doctor expects com.dotfiles.endpoint-bootstrap only when apply installs
# it: endpoint_hardening on (same default as apply).

load test_helper

@test "security doctor checks endpoint-bootstrap only with endpoint_hardening on" {
  DOCTOR="$BATS_TEST_DIRNAME/../modules/security/doctor.sh"
  grep -B2 '"security.endpoint_bootstrap_la"' "$DOCTOR" | grep -q 'if \[ "${ENDPOINT_HARDENING:-true}" = "true" \]; then'
}

@test "doctor reads endpoint_hardening with the launchagents default" {
  grep -q 'dig "endpoint_hardening" true .' "$BATS_TEST_DIRNAME/../bin/dotfiles-doctor"
  grep -q 'dig "endpoint_hardening" true .' "$BATS_TEST_DIRNAME/../.chezmoiscripts/run_onchange_launchagents.sh.tmpl"
}
