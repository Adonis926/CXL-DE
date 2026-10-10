#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi

artifact_dir=/home/xtl/GVM-SHM/variants/cohort/artifacts-guest-driven-private-tiering-20260812
kvm_module="$artifact_dir/kvm.ko"
kvm_intel_module="$artifact_dir/kvm-intel.ko"
manifest="$artifact_dir/MANIFEST"
checksums="$artifact_dir/SHA256SUMS"

manifest_value() {
    local key=$1
    sed -n "s/^${key}=//p" "$manifest"
}

gvm_workers() {
    ps -eLo pid=,tid=,comm= |
        awk '$3 ~ /^(gvm-private\/|gvm-cxl-irq\/|ktcp)/'
}

[[ $(uname -r) == 6.6.32-shm+ ]] || {
    echo "host must run 6.6.32-shm+, found $(uname -r)" >&2
    exit 1
}
[[ -f $kvm_module && -f $kvm_intel_module ]] || {
    echo "native-capable KVM artifacts are missing" >&2
    exit 1
}
(cd "$artifact_dir" && sha256sum -c "$(basename "$checksums")") >/dev/null
modinfo -p "$kvm_module" |
    grep -q '^gvm_irq_userspace_forwarding:' || {
    echo "KVM artifact does not support selectable IRQ forwarding" >&2
    exit 1
}

if [[ -e /dev/kvm ]] && fuser /dev/kvm >/dev/null 2>&1; then
    echo "cannot switch KVM modules while a VM is using /dev/kvm:" >&2
    fuser -v /dev/kvm >&2 || true
    exit 1
fi
if [[ -n $(gvm_workers) ]]; then
    echo "stale GVM kernel workers remain" >&2
    gvm_workers >&2
    exit 1
fi
if find /sys/kernel/debug/kvm -mindepth 1 -maxdepth 1 -type d \
        -print -quit 2>/dev/null | grep -q .; then
    echo "stale KVM debugfs VMs remain" >&2
    exit 1
fi

if [[ -d /sys/module/kvm_intel ]]; then
    modprobe -r kvm_intel
fi
if [[ -d /sys/module/kvm ]]; then
    modprobe -r kvm
fi
modprobe irqbypass

insmod "$kvm_module" \
    gvm_irq_enabled=0 gvm_irq_userspace_forwarding=0 \
    gvm_private_access_sampling=0 \
    gvm_private_migration_enabled=0
if ! insmod "$kvm_intel_module" enable_apicv=0 dump_invalid_vmcs=0; then
    modprobe -r kvm
    exit 1
fi

expected_srcversion=$(manifest_value kvm_srcversion)
[[ $(cat /sys/module/kvm/srcversion) == "$expected_srcversion" &&
   $(cat /sys/module/kvm/parameters/gvm_irq_enabled) == N &&
   $(cat /sys/module/kvm/parameters/gvm_irq_userspace_forwarding) == N &&
   $(cat /sys/module/kvm_intel/parameters/enable_apicv) == N ]] || {
    echo "native KVM mode validation failed" >&2
    modprobe -r kvm_intel kvm
    exit 1
}
[[ -c /dev/kvm ]] || {
    echo "/dev/kvm is unavailable after loading the modules" >&2
    exit 1
}

echo "Native KVM modules are ready"
echo "host_kernel=$(uname -r)"
echo "kvm_srcversion=$(cat /sys/module/kvm/srcversion)"
echo "gvm_irq_enabled=$(cat /sys/module/kvm/parameters/gvm_irq_enabled)"
echo "gvm_irq_userspace_forwarding=$(cat /sys/module/kvm/parameters/gvm_irq_userspace_forwarding)"
echo "gvm_private_access_sampling=$(cat /sys/module/kvm/parameters/gvm_private_access_sampling)"
echo "gvm_private_migration_enabled=$(cat /sys/module/kvm/parameters/gvm_private_migration_enabled)"
echo "enable_apicv=$(cat /sys/module/kvm_intel/parameters/enable_apicv)"
