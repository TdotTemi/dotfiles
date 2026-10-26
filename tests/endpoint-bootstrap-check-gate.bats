#!/usr/bin/env bats
# The doctor expects com.dotfiles.endpoint-bootstrap only when apply installs
# it: endpoint_hardening on (same default as apply).

load test_helper

@test "security doctor checks endpoint-bootstrap only with endpoint_hardening on" {
  DOCTOR="$BATS_TEST_DIRNAME/../modules/security/doctor.sh"
  grep -B2 '"security.endpoint_bootstrap_la"' "$DOCTOR" | grep -q 'if \[ "$_endpoint_hardening_on" = "true" \]; then'
}

@test "doctor reads endpoint_hardening with the launchagents default" {
  grep -q 'dig "endpoint_hardening" true .' "$BATS_TEST_DIRNAME/../bin/dotfiles-doctor"
  grep -q 'dig "endpoint_hardening" true .' "$BATS_TEST_DIRNAME/../.chezmoiscripts/run_onchange_launchagents.sh.tmpl"
}

# Run the gated block with stub check functions; print the check ids it adds.
_bootstrap_checks() {
  local block
  block="$(sed -n '/^# Apply installs endpoint-bootstrap only/,/^fi$/p' "$BATS_TEST_DIRNAME/../modules/security/doctor.sh")"
  ( ENDPOINT_HARDENING="$1"; check() { echo "$1"; }; check_advisory() { echo "$1"; }; eval "$block" )
}

@test "endpoint_hardening on (true or 1) runs the endpoint-bootstrap checks" {
  for v in true 1 ""; do
    run _bootstrap_checks "$v"
    [[ "$output" == *"security.endpoint_bootstrap_la"* ]]
    [[ "$output" == *"security.endpoint_bootstrap_sentinel"* ]]
  done
}

@test "endpoint_hardening off (false or 0) skips the endpoint-bootstrap checks" {
  for v in false 0; do
    run _bootstrap_checks "$v"
    [ -z "$output" ]
  done
}
