# CXL-DE Source Manifest

This repository is the top-level source manifest for the CXL-DE system used by
the Cohort evaluation.  CXL-DE combines CXLfork execution-context activation
with HydraRPC communication.  It contains both the distributed PageRank path
and the OpenWhisk end-to-end path evaluated in Cohort.

The implementation is split into independent repositories:

```text
cxlfork/                         VM launch/control repository
  kernel/linux-6.6.32/          CXLfork guest kernel (nested submodule)
  cxlporter/                     CXLfork helper library (nested submodule)
hydrarpc/                        shared-memory RPC runtime
pagerank/                        PageRank user-space program and experiment runner
qemu/                            upstream QEMU used by the evaluated setup
openwhisk/                       custom OpenWhisk source used by Figure 9
openwhisk-e2e/                   frozen Figure 9 controller and CXLfork closure
  kernel/linux-6.6.32/           OpenWhisk experiment guest kernel
  cxlporter/                     OpenWhisk CXLfork state-transfer helpers
```

Do not select component branches independently.  The superproject gitlinks and
`versions/cxlde.env` pin the exact source closure that was validated together.

## Clone

```bash
git clone git@github.com:Adonis926/CXL-DE.git
cd CXL-DE
./scripts/checkout-components.sh
```

The newly separated HydraRPC, PageRank, and OpenWhisk repositories are public.
The historical CXLfork orchestration, kernel, and CXLporter remotes still
require team access; on Lux the checkout script automatically uses the
read-only recovery mirrors.  The locked commits in `versions/cxlde.env` are
the authoritative source versions.

## Lux quick start

On Lux, existing VM images, cloud-init media, kernel/QEMU builds, and the SSH
key can be reused without copying them into Git:

```bash
./scripts/bootstrap-lux.sh
./scripts/status.sh
./scripts/run-pagerank.sh 8 --check
./scripts/run-pagerank.sh 8
./scripts/run-openwhisk.sh preflight
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

## OpenWhisk E2E

The OpenWhisk path defaults to the CXL-DE/CXLfork system only.  `preflight` is
read-only.  `provision` creates a new experiment disk and new qcow2 overlays
under this checkout, leaving the historical campaign directory untouched.

```bash
./scripts/run-openwhisk.sh preflight
sudo -E ./scripts/run-openwhisk.sh provision
sudo -E ./scripts/run-openwhisk.sh run figure9 8 16 32 64 80
./scripts/run-openwhisk.sh status figure9
```

The backend can be selected explicitly without changing the experiment:

```bash
./scripts/run-openwhisk.sh --backend reserved-dram preflight
sudo -E ./scripts/run-openwhisk.sh --backend reserved-dram run figure9 8 16 32 64 80
./scripts/run-openwhisk.sh --backend real-cxl preflight
```

The runner resolves the actual `/dev/dax*` device and its required mapping
alignment at runtime.  It preserves the paper layout: CXLfork uses `[4,8) GiB`
and HydraRPC uses `[8,12) GiB`.  Runtime JDK/JAR/CLI assets are hash-checked
against `versions/cxlde.env`.

## Build from source

```bash
./scripts/build.sh kernel
./scripts/build.sh qemu
./scripts/build.sh pagerank
./scripts/build.sh openwhisk
./scripts/build.sh openwhisk-e2e
```

The OpenWhisk build automatically uses the validated JDK 11 linked by
`bootstrap-lux.sh`; on another host set `OPENWHISK_JAVA_HOME` to a JDK 11
installation.  It does not change the host-wide Java selection.

Or build all components in dependency order:

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
