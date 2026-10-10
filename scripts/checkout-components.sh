#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LOCK=$ROOT/versions/cxlde.env

# shellcheck source=/dev/null
source "$LOCK"

git -C "$ROOT" submodule sync --recursive
git -C "$ROOT" submodule update --init \
  cxlfork hydrarpc pagerank qemu openwhisk openwhisk-e2e
git -C "$ROOT/cxlfork" submodule sync
git -C "$ROOT/openwhisk-e2e" submodule sync

if [[ $(hostname -s) == Lux && -d /home/xtl/cxlfork/cxlfork-repro/kernel/linux-6.6.32 ]]; then
  # Lux keeps recovery mirrors for the private historical component remotes.
  # The overrides are invocation-local and do not alter the locked gitlinks.
  git -C "$ROOT/cxlfork" -c protocol.file.allow=always \
    -c submodule.kernel/linux-6.6.32.url=/home/xtl/cxlfork/cxlfork-repro/kernel/linux-6.6.32 \
    -c submodule.cxlporter.url=/home/xtl/cxlfork/cxlfork-repro/.git/modules/cxlporter \
    submodule update --init kernel/linux-6.6.32 cxlporter
  git -C "$ROOT/openwhisk-e2e" -c protocol.file.allow=always \
    -c submodule.kernel/linux-6.6.32.url=/home/xtl/cxlfork/cxlfork-repro/kernel/linux-6.6.32 \
    -c submodule.cxlporter.url=/home/xtl/cxlfork/cxlfork-repro/.git/worktrees/openwhisk-state-action-eval/modules/cxlporter \
    submodule update --init kernel/linux-6.6.32 cxlporter
else
  git -C "$ROOT/cxlfork" submodule update --init \
    kernel/linux-6.6.32 cxlporter
  git -C "$ROOT/openwhisk-e2e" submodule update --init \
    kernel/linux-6.6.32 cxlporter
fi

check_head() {
  local label=$1 path=$2 expected=$3 actual
  actual=$(git -C "$path" rev-parse HEAD)
  [[ $actual == "$expected" ]] || {
    printf '%s commit mismatch: %s != %s\n' "$label" "$actual" "$expected" >&2
    exit 1
  }
  if ! git -C "$path" diff --quiet || ! git -C "$path" diff --cached --quiet; then
    echo "$label has tracked local changes" >&2
    exit 1
  fi
  printf '%-16s %s\n' "$label" "$actual"
}

check_head cxlfork "$ROOT/cxlfork" "$CXLFORK_COMMIT"
check_head kernel "$ROOT/cxlfork/kernel/linux-6.6.32" "$CXLFORK_KERNEL_COMMIT"
check_head cxlporter "$ROOT/cxlfork/cxlporter" "$CXLPORTER_COMMIT"
check_head hydrarpc "$ROOT/hydrarpc" "$HYDRARPC_COMMIT"
check_head pagerank "$ROOT/pagerank" "$PAGERANK_COMMIT"
check_head qemu "$ROOT/qemu" "$QEMU_COMMIT"
check_head openwhisk "$ROOT/openwhisk" "$OPENWHISK_COMMIT"
check_head openwhisk-e2e "$ROOT/openwhisk-e2e" "$OPENWHISK_E2E_COMMIT"
check_head owe-kernel "$ROOT/openwhisk-e2e/kernel/linux-6.6.32" "$OPENWHISK_KERNEL_COMMIT"
check_head owe-cxlporter "$ROOT/openwhisk-e2e/cxlporter" "$OPENWHISK_CXLPORTER_COMMIT"

echo "CXL-DE component checkout is locked and clean"
