#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

export CXLDE_ROOT=$ROOT
export CXLFORK_VM_WORKSPACE=$ROOT/cxlfork
export CXLFORK_LOAD_KVM=$ROOT/scripts/runtime/load-native-kvm-lux.sh
export PR_PROFILE_OVERRIDE=$ROOT/pagerank/config/pagerank-real-cxl-103-direct-scaling.env
export PR_RESULT_ROOT=$ROOT/results/pagerank-cxlfork-hydrarpc

exec "$ROOT/pagerank/scripts/run-pagerank-manual.sh" "$@"
