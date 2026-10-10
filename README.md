# CXL-DE Source Manifest

This repository is the top-level source manifest for the CXL-DE system used by
the Cohort evaluation.  CXL-DE combines CXLfork execution-context activation
with HydraRPC communication and runs the distributed PageRank workload in two
QEMU/KVM guests.

The implementation is split into independent repositories:

```text
cxlfork/                         VM launch/control repository
  kernel/linux-6.6.32/          CXLfork guest kernel (nested submodule)
  cxlporter/                     CXLfork helper library (nested submodule)
hydrarpc/                        shared-memory RPC runtime
pagerank/                        PageRank user-space program and experiment runner
qemu/                            upstream QEMU used by the evaluated setup
```

Do not select component branches independently.  The superproject gitlinks and
`versions/cxlde.env` pin the exact source closure that was validated together.

## Clone

```bash
git clone git@github.com:Adonis926/CXL-DE.git
cd CXL-DE
./scripts/checkout-components.sh
```

All source submodules use public GitHub repositories. The team `sync91` mirrors
remain only as recovery copies and are not required by this checkout. The
locked commits in `versions/cxlde.env` are the authoritative source versions.

## Lux quick start

On Lux, existing VM images, cloud-init media, kernel/QEMU builds, and the SSH
key can be reused without copying them into Git:

```bash
./scripts/bootstrap-lux.sh
./scripts/status.sh
./scripts/run-pagerank.sh 8 --check
./scripts/run-pagerank.sh 8
```

The PageRank runner automatically selects the reserved-DRAM backend when the
host command line contains `memmap=64G!0x5040000000`; otherwise it selects the
real-CXL path.  The explicit forms are:

```bash
./scripts/run-pagerank.sh 8 --backend reserved-dram
./scripts/run-pagerank.sh 8 --backend real-cxl
```

The real-CXL device must first be placed in devdax mode using the preserved
administrator flow.  The reserved-DRAM runner prepares only the exact e820
namespace and clears only the locked device-relative range `[4,12) GiB`.

## Build from source

```bash
./scripts/build.sh kernel
./scripts/build.sh qemu
./scripts/build.sh pagerank
```

Or build all three in dependency order:

```bash
./scripts/build.sh all
```

The checked-in kernel config is the exact config captured from the validated
Lux build.  Build outputs, guest images, keys, logs, and experiment results are
deliberately excluded from the repository.

## What is not a source submodule

- VM disk images and cloud-init seed images are runtime assets, not source.
- `/dev/dax*` devices and the `memmap` reservation are host configuration.
- `scripts/runtime/load-native-kvm-lux.sh` records the validated Lux module
  loader and therefore retains its server-local artifact path, as Cohort's
  runtime scripts do.
