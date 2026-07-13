#!/usr/bin/env bash
#
# mayhem/test.sh — RUN xori's own upstream test suite (already built by
# mayhem/build.sh via `cargo test --lib --no-run`) and report CTRF counts.
#
# Upstream's entire test suite lives in src/test.rs (pub mod test in lib.rs):
# 34 #[test] known-answer disassembly tests that assert exact mnemonic/operand
# strings for x86 instruction encodings (16/32/64-bit) via assert_eq!. There is
# no other suite (no tests/ dir, no CI harness upstream). The bin/gui trees
# carry no Rust tests, so `cargo test --lib` IS the whole upstream suite.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

LOG=/tmp/cargo-test.log
env RUSTFLAGS="-Asemicolon_in_expressions_from_macros" cargo test --lib >"$LOG" 2>&1
rc=$?
cat "$LOG"

# Sum the per-binary "test result: ok. N passed; M failed; K ignored; ... Z filtered out"
read -r PASSED FAILED SKIPPED <<<"$(awk '
  /^test result:/ {
    for (i = 1; i <= NF; i++) {
      if ($(i+1) ~ /^passed/)   p += $i
      if ($(i+1) ~ /^failed/)   f += $i
      if ($(i+1) ~ /^ignored/)  s += $i
      if ($(i+1) ~ /^filtered/) s += $i
    }
  }
  END { printf "%d %d %d", p+0, f+0, s+0 }' "$LOG")"

if ! grep -q '^test result:' "$LOG"; then
  echo "ERROR: no 'test result:' lines — the pre-built test suite did not run (build.sh bug?)" >&2
  emit_ctrf cargo-test 0 1 0
  exit 1
fi
[ "$rc" -ne 0 ] && [ "$FAILED" -eq 0 ] && FAILED=1   # non-zero cargo exit with no parsed failure still fails

emit_ctrf cargo-test "$PASSED" "$FAILED" "$SKIPPED"
