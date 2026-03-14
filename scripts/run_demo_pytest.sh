#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run pytest inside the hololink demo container.
# Usage examples:
#   scripts/run_demo_pytest.sh
#   scripts/run_demo_pytest.sh --emulator
#   scripts/run_demo_pytest.sh --hw-loopback IF1,IF2 -- -k linux

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTEST_ARGS=()
PASSTHRU=()
HW_LOOPBACK=""
RUN_EMULATOR=0

usage() {
  cat <<'USAGE'
Usage: scripts/run_demo_pytest.sh [options] [pytest args]
       scripts/run_demo_pytest.sh [options] -- [pytest args]
Options:
  --hw-loopback IF1,IF2   Add pytest --hw-loopback IF1,IF2
  --emulator              Add pytest --emulator
  -h, --help              Show this help
Arguments before "--" are appended after the generated options.
Anything after "--" is forwarded verbatim to pytest.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hw-loopback)
      HW_LOOPBACK="$2"
      shift 2
      ;;
    --emulator)
      RUN_EMULATOR=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      PASSTHRU=("$@")
      break
      ;;
    *)
      PYTEST_ARGS+=("$1")
      shift
      ;;
  esac
done

cd "$REPO_ROOT"

CMD=(pytest)
if [[ "$RUN_EMULATOR" -eq 1 ]]; then
  CMD+=(--emulator)
fi
if [[ -n "$HW_LOOPBACK" ]]; then
  CMD+=(--hw-loopback "$HW_LOOPBACK")
fi
if [[ ${#PYTEST_ARGS[@]} -gt 0 ]]; then
  CMD+=("${PYTEST_ARGS[@]}")
fi
if [[ ${#PASSTHRU[@]} -gt 0 ]]; then
  CMD+=("${PASSTHRU[@]}")
fi

set -x
sh docker/demo.sh "${CMD[@]}"
