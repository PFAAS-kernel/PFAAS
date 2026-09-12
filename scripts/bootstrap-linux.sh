#!/usr/bin/env bash
set -euo pipefail

install_packages() {
  if [[ $EUID -eq 0 ]]; then local elevate=(); else local elevate=(sudo -n); fi
  export DEBIAN_FRONTEND=noninteractive
  "${elevate[@]}" apt-get update
  "${elevate[@]}" apt-get install -y --no-install-recommends \
  build-essential binutils cmake ninja-build pkg-config libc6-dev libelf-dev elfutils \
  python3 python3-venv python3-pip git gdb clang llvm llvm-dev lld \
  qemu-system-x86 qemu-utils qemu-system-data \
  autoconf automake bc bison flex cpio file jq libncurses-dev libssl-dev \
  libtool meson patch rsync unzip wget xz-utils zstd
}

if [[ "${1:-}" == --packages-only ]]; then install_packages; exit 0; fi

if [[ "$(uname -s)" != Linux ]] || { grep -qi microsoft /proc/version && [[ "${PWD,,}" == /mnt/* ]]; }; then
  echo "Run this script from the Linux filesystem (for example ~/pfaas), not /mnt/c." >&2
  exit 2
fi

if [[ "${PFAAS_SKIP_PACKAGES:-0}" != 1 ]]; then install_packages; fi

# Buildroot rejects WSL's Windows-appended PATH (which may contain spaces), and
# all requested build work must resolve Linux tools only.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export WGETRC="$PWD/config/wgetrc"

mkdir -p \
  compiler/{passes,analyses,transforms} \
  runtime/{app_context,scheduler,io,memory,platform} \
  workloads/{synthetic,real} \
  linux-baseline/{kernel-config,buildroot-config} \
  unikernel-baseline fleet/{corpus,variants,canonicalization,placement} \
  engines/{hashing,compression,regex,storage} \
  experiments/{single-image,multi-app,fleet-dedup,shared-engine} \
  measurements/{image-size,code-size,rss,page-sharing,boot-time,cpu} \
  tools/{ir-inspection,binary-analysis,corpus-generation} \
  docs/{architecture,research-notes} build verification

clone_or_update() {
  local url="$1" ref="$2" target="$3" expected="$4"
  if [[ -d "$target/.git" ]]; then
    if [[ "$(git -C "$target" rev-parse HEAD 2>/dev/null || true)" == "$expected" ]]; then return; fi
    git -C "$target" fetch --depth 1 origin "$ref"
    git -C "$target" checkout --detach FETCH_HEAD
  else
    git clone --depth 1 --branch "$ref" "$url" "$target"
  fi
  [[ "$(git -C "$target" rev-parse HEAD)" == "$expected" ]]
}

# Pinned source revisions avoid silently changing the reference environments.
clone_or_update https://github.com/unikraft/unikraft.git RELEASE-0.18.0 unikernel-baseline/unikraft 424eb3d920bfbe9ca0dc269750fba4a989ead184

install_buildroot() {
  local version=2025.02.5 target=linux-baseline/buildroot
  if [[ -f "$target/Makefile" ]] && grep -q '^export BR2_VERSION := 2025.02.5$' "$target/Makefile"; then return; fi
  local archive tempdir
  tempdir="$(mktemp -d)"
  archive="$tempdir/buildroot-$version.tar.xz"
  wget --tries=3 --timeout=30 -O "$archive" "https://buildroot.org/downloads/buildroot-$version.tar.xz"
  if [[ -e "$target" ]]; then mv "$target" "$tempdir/incomplete-buildroot"; fi
  mkdir -p "$target"
  tar -xJf "$archive" --strip-components=1 -C "$target"
  rm -rf "$tempdir"
}
install_buildroot

if [[ ! -d .git ]]; then
  git init
fi

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./scripts/build-llvm-lab.sh
./scripts/build-freestanding.sh
make -C linux-baseline/buildroot O="$PWD/build/buildroot" \
  BR2_DEFCONFIG="$PWD/linux-baseline/buildroot-config/pfaas_x86_64_defconfig" defconfig
make -C linux-baseline/buildroot O="$PWD/build/buildroot" -j"$(nproc)"
./scripts/test-buildroot-qemu.sh
./scripts/verify-desired-state.sh
