#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BACKEND=auto

if [[ ${1:-} == --backend ]]; then
  [[ $# -ge 2 ]] || { echo "--backend needs auto, reserved-dram, or real-cxl" >&2; exit 2; }
  BACKEND=$2
  shift 2
fi

case "$BACKEND" in
  auto|reserved-dram|real-cxl) ;;
  *) echo "invalid backend: $BACKEND" >&2; exit 2 ;;
esac

COMMAND=${1:-}
[[ -n $COMMAND ]] || {
  echo "usage: $0 [--backend BACKEND] {preflight|provision|run|status|summarize} [...]" >&2
  exit 2
}
shift

export OWE_PROFILE="$ROOT/openwhisk-e2e/config/openwhisk-state-action-eval-103.env"
export OWE_SYSTEMS=cxlfork
export OWE_ROOT="$ROOT/runtime/openwhisk"
export OWE_RESULT_ROOT="$ROOT/results/openwhisk"
export OWE_ASSET_ROOT="$ROOT/runtime/openwhisk/assets"
export OWE_SSI_DISK="$ROOT/runtime/openwhisk/images/ssi-openwhisk.raw"
export OWE_SSI_BASE_DISK="$ROOT/runtime/openwhisk/ssi-base.raw"
export OWE_CXL_WS="$ROOT/runtime/openwhisk/cxlfork-vms"
export OWE_HPCA_DIR=/home/xtl/start/hpca
export OWE_QEMU="$ROOT/qemu/build/qemu-system-x86_64"
export OWE_KERNEL="$ROOT/runtime/openwhisk/kernel/bzImage-6.6.32-cxlfork-91"
export OWE_KVM_LOADER="$ROOT/scripts/runtime/load-native-kvm-lux.sh"
export OWE_SSH_KEY="$ROOT/runtime/keys/id_ed25519"
export OWE_CXL_BASE_IMAGE_ROOT="$ROOT/runtime/openwhisk/base-images"
export OWE_CLOUDINIT_ROOT="$ROOT/runtime/openwhisk/cloudinit"
export OWE_BACKEND_HELPER="$ROOT/pagerank/scripts/cxlde-shared-backend.sh"
export OWE_SHARED_BACKEND=$BACKEND

case "$COMMAND" in
  run|status|summarize)
    [[ $# -ge 1 ]] || { echo "$COMMAND needs a campaign name" >&2; exit 2; }
    campaign=$1
    shift
    [[ $campaign == /* ]] || campaign="$OWE_RESULT_ROOT/$campaign"
    set -- "$campaign" "$@"
    ;;
esac

exec "$ROOT/openwhisk-e2e/scripts/run-openwhisk-state-action-eval.sh" "$COMMAND" "$@"
