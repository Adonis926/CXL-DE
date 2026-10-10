#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
JOBS=${JOBS:-$(nproc)}
# shellcheck source=/dev/null
source "$ROOT/versions/cxlde.env"

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
  cmake --build "$output" --target pagerank_hydra -j"$JOBS"
  sha256sum "$output/pagerank_hydra"
}

build_openwhisk() {
  local java_home=${OPENWHISK_JAVA_HOME:-$ROOT/runtime/openwhisk/assets/jdk-11}
  local swagger=${OPENWHISK_SWAGGER_TARBALL:-$ROOT/runtime/openwhisk/build-cache/swagger-ui-v3.6.0.tar.gz}
  local swagger_dest=$ROOT/openwhisk/core/standalone/build/tmp/swagger/swagger-ui.tar
  [[ -x $java_home/bin/java ]] || {
    echo "OpenWhisk requires JDK 11; run bootstrap-lux.sh or set OPENWHISK_JAVA_HOME" >&2
    return 1
  }
  if [[ -r $swagger ]]; then
    [[ $(sha256sum "$swagger" | awk '{print $1}') == "$OPENWHISK_SWAGGER_UI_SHA256" ]] || {
      echo "Swagger UI build asset has the wrong SHA256: $swagger" >&2
      return 1
    }
    mkdir -p "$(dirname "$swagger_dest")"
    install -m 0644 "$swagger" "$swagger_dest"
  fi
  (cd "$ROOT/openwhisk" && \
    env JAVA_HOME="$java_home" PATH="$java_home/bin:$PATH" \
      ./gradlew --no-daemon :core:standalone:bootJar)
  sha256sum "$ROOT/openwhisk/bin/openwhisk-standalone.jar"
}

build_openwhisk_e2e() {
  make -C "$ROOT/openwhisk-e2e/cxlporter" -j"$JOBS"
  sha256sum \
    "$ROOT/openwhisk-e2e/cxlporter/state-action-http" \
    "$ROOT/openwhisk-e2e/cxlporter/state-action-capsule" \
    "$ROOT/openwhisk-e2e/cxlporter/cxlporter-paper" \
    "$ROOT/openwhisk-e2e/cxlporter/cxlfork-ghost-agent"
}

if (( $# == 0 )); then
  echo "usage: $0 {kernel|qemu|pagerank|openwhisk|openwhisk-e2e|all} [...]" >&2
  exit 2
fi

for component in "$@"; do
  case "$component" in
    kernel) build_kernel ;;
    qemu) build_qemu ;;
    pagerank) build_pagerank ;;
    openwhisk) build_openwhisk ;;
    openwhisk-e2e) build_openwhisk_e2e ;;
    all)
      build_kernel
      build_qemu
      build_pagerank
      build_openwhisk
      build_openwhisk_e2e
      ;;
    *) echo "unknown component: $component" >&2; exit 2 ;;
  esac
done
