#!/usr/bin/env bats
# dotfiles-doctor runs each fix in a new process (`bash -c "$cmd"`), so a fix
# that calls a function defined in its module must `export -f` it. The
# jetbrains plugin fix missed this and failed on every Mac.

load test_helper

@test "every fix that calls a module function exports that function" {
  cd "$BATS_TEST_DIRNAME/.."
  local f fn line missing=""
  for f in modules/*/doctor.sh; do
    for fn in $(grep -oE '^[[:space:]]*_?[A-Za-z_][A-Za-z0-9_]*\(\)' "$f" | tr -d ' ()' | sort -u); do
      # A fix is the last argument of check: a line holding only one quoted
      # string that starts with the function name.
      line="^[[:space:]]+\"$fn( [^\"]*)?\"[[:space:]]*\$"
      grep -qE "$line" "$f" || continue
      # check_advisory has no fix; its last argument is a test, run in-process.
      grep -B3 -E "$line" "$f" | grep -q '^check_advisory' && continue
      grep -qE "export -f .*\b$fn\b" "$f" || missing="$missing $f:$fn"
    done
  done
  [ -z "$missing" ] || { echo "not exported:$missing"; false; }
}

@test "dotfiles-doctor still runs fixes in a new bash process" {
  grep -q 'bash -c "$cmd"' "$BATS_TEST_DIRNAME/../bin/dotfiles-doctor"
}
