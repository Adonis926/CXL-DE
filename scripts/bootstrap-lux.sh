#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ $(hostname -s) == Lux ]] || {
  echo "bootstrap-lux.sh is restricted to host Lux" >&2
  exit 1
}

link_asset() {
  local source=$1 destination=$2
  [[ -e $source ]] || {
    echo "missing Lux asset: $source" >&2
    exit 1
  }
  if [[ -L $destination && $(readlink -f "$destination") == $(readlink -f "$source") ]]; then
    printf 'reuse %s -> %s\n' "$destination" "$source"
    return
  fi
  [[ ! -e $destination && ! -L $destination ]] || {
    echo "refusing to replace existing path: $destination" >&2
    exit 1
  }
  mkdir -p "$(dirname "$destination")"
  ln -s "$source" "$destination"
  printf 'link  %s -> %s\n' "$destination" "$source"
}

link_asset /home/xtl/cxlfork/cxlfork-repro/images "$ROOT/cxlfork/images"
link_asset /home/xtl/cxlfork/cxlfork-repro/cloudinit "$ROOT/cxlfork/cloudinit"
link_asset /home/xtl/cxlfork/cxlfork-repro/kernel/build-6.6.32 \
  "$ROOT/cxlfork/kernel/build-6.6.32"
link_asset /home/xtl/qemu-9.0.90-clean/build "$ROOT/qemu/build"
link_asset /home/xtl/start/hpca-cxlfork/keys/id_ed25519 \
  "$ROOT/runtime/keys/id_ed25519"
mkdir -p "$ROOT/results/pagerank-cxlfork-hydrarpc"

# OpenWhisk source is tracked as submodules; only the large, validated runtime
# inputs remain server-local.  The new workspace and overlays are deliberately
# not linked to the historical campaign directory.
link_asset /home/xtl/start/hpca-openwhisk-eval/assets \
  "$ROOT/runtime/openwhisk/assets"
link_asset /home/xtl/start/hpca/private-master.raw \
  "$ROOT/runtime/openwhisk/ssi-base.raw"
link_asset /home/xtl/start/hpca-cxlfork/images \
  "$ROOT/runtime/openwhisk/base-images"
link_asset /home/xtl/start/hpca-cxlfork/cloudinit \
  "$ROOT/runtime/openwhisk/cloudinit"
link_asset /home/xtl/start/hpca-cxlfork/kernels/bzImage-6.6.32-cxlfork-91 \
  "$ROOT/runtime/openwhisk/kernel/bzImage-6.6.32-cxlfork-91"
link_asset /home/xtl/start/cxlde-assets/openwhisk/swagger-ui-v3.6.0.tar.gz \
  "$ROOT/runtime/openwhisk/build-cache/swagger-ui-v3.6.0.tar.gz"
mkdir -p "$ROOT/runtime/openwhisk/cxlfork-vms" "$ROOT/results/openwhisk"

echo "Lux runtime assets are linked; no source or image was copied"
