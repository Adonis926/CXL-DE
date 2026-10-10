#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$ROOT/versions/cxlde.env"

status=0
show_component() {
  local label=$1 path=$2 expected=$3 actual dirty
  if ! git -C "$path" rev-parse HEAD >/dev/null 2>&1; then
    printf '%-16s missing (expected %s)\n' "$label" "$expected"
    status=1
    return
  fi
  actual=$(git -C "$path" rev-parse HEAD)
  dirty=$(git -C "$path" status --short --untracked-files=no)
  printf '%-16s %s expected=%s%s\n' "$label" "$actual" "$expected" \
    "$([[ -n $dirty ]] && echo ' dirty=tracked' || true)"
  [[ $actual == "$expected" && -z $dirty ]] || status=1
}

show_component cxlfork "$ROOT/cxlfork" "$CXLFORK_COMMIT"
show_component kernel "$ROOT/cxlfork/kernel/linux-6.6.32" "$CXLFORK_KERNEL_COMMIT"
show_component cxlporter "$ROOT/cxlfork/cxlporter" "$CXLPORTER_COMMIT"
show_component hydrarpc "$ROOT/hydrarpc" "$HYDRARPC_COMMIT"
show_component pagerank "$ROOT/pagerank" "$PAGERANK_COMMIT"
show_component qemu "$ROOT/qemu" "$QEMU_COMMIT"

config_hash=$(sha256sum "$ROOT/configs/cxlfork-guest-6.6.32.config" | awk '{print $1}')
printf '%-16s %s expected=%s\n' kernel-config "$config_hash" "$KERNEL_CONFIG_SHA256"
[[ $config_hash == "$KERNEL_CONFIG_SHA256" ]] || status=1

if [[ -x $ROOT/qemu/build/qemu-system-x86_64 ]]; then
  hash=$(sha256sum "$ROOT/qemu/build/qemu-system-x86_64" | awk '{print $1}')
  printf '%-16s %s validated=%s\n' qemu-binary "$hash" "$VALIDATED_QEMU_SHA256"
fi
if [[ -f $ROOT/cxlfork/kernel/build-6.6.32/arch/x86/boot/bzImage ]]; then
  hash=$(sha256sum "$ROOT/cxlfork/kernel/build-6.6.32/arch/x86/boot/bzImage" | awk '{print $1}')
  printf '%-16s %s validated=%s\n' kernel-image "$hash" "$VALIDATED_KERNEL_IMAGE_SHA256"
fi

if [[ -x $ROOT/pagerank/scripts/cxlde-shared-backend.sh ]]; then
  echo
  "$ROOT/pagerank/scripts/cxlde-shared-backend.sh" status auto
fi

exit "$status"
