#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LOCK=$ROOT/versions/cxlde.env

# shellcheck source=/dev/null
source "$LOCK"

git -C "$ROOT" submodule sync --recursive
git -C "$ROOT" submodule update --init cxlfork hydrarpc pagerank qemu
git -C "$ROOT/cxlfork" submodule sync
git -C "$ROOT/cxlfork" submodule update --init \
  kernel/linux-6.6.32 cxlporter

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

echo "CXL-DE component checkout is locked and clean"
