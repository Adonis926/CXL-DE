#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
JOBS=${JOBS:-$(nproc)}

build_kernel() {
  local source=$ROOT/cxlfork/kernel/linux-6.6.32
  local output=$ROOT/cxlfork/kernel/build-6.6.32
  mkdir -p "$output"
  install -m 0644 "$ROOT/configs/cxlfork-guest-6.6.32.config" "$output/.config"
  make -C "$source" O="$output" olddefconfig
  make -C "$source" O="$output" -j"$JOBS" bzImage modules
  make -C "$source" O="$output" \
    INSTALL_HDR_PATH="$output/usr" headers_install
  sha256sum "$output/arch/x86/boot/bzImage"
}

build_qemu() {
  local source=$ROOT/qemu
  local output=$ROOT/qemu/build
  if [[ ! -f $output/build.ninja ]]; then
    mkdir -p "$output"
    (cd "$output" && ../configure \
      --target-list=x86_64-softmmu --disable-docs)
  fi
  ninja -C "$output" -j"$JOBS"
  "$output/qemu-system-x86_64" --version | head -1
  sha256sum "$output/qemu-system-x86_64"
}

build_pagerank() {
  local source=$ROOT/pagerank
  local output=$ROOT/pagerank/build-pagerank
  local uapi=$ROOT/cxlfork/kernel/build-6.6.32/usr/include
  cmake -S "$source" -B "$output" \
    -DHYDRARPC_ROOT="$ROOT/hydrarpc" \
    -DMR_ENABLE_CXLFORK=ON \
    -DCXLFORK_UAPI_INCLUDE_DIR="$uapi"
  cmake --build "$output" -j"$JOBS"
  sha256sum "$output/pagerank_hydra"
}

if (( $# == 0 )); then
  echo "usage: $0 {kernel|qemu|pagerank|all} [...]" >&2
  exit 2
fi

for component in "$@"; do
  case "$component" in
    kernel) build_kernel ;;
    qemu) build_qemu ;;
    pagerank) build_pagerank ;;
    all)
      build_kernel
      build_qemu
      build_pagerank
      ;;
    *) echo "unknown component: $component" >&2; exit 2 ;;
  esac
done
