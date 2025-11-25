#!/usr/bin/env bash
# Build two armhf rootfs tarballs:
#  - Debian Buster base rootfs: out/rootfs-buster-armhf.tar.xz
#  - Debian Stretch eclipse desktop rootfs: out/eclipse-desktop-stretch-armhf.tar.xz
#
# Usage: ./scripts/build-bootstrap.sh
# This script runs inside Docker on an x86_64 Linux host and requires Docker.
set -euo pipefail

OUTDIR="${PWD}/out"
mkdir -p "$OUTDIR"
DEBIAN_MIRROR="http://deb.debian.org/debian"
ARCH="armhf"

echo "Building Debian Buster (armhf) base rootfs..."
docker run --rm -v "$OUTDIR:/out" --privileged debian:bookworm-slim bash -c "\
  apt-get update && apt-get install -y --no-install-recommends debootstrap qemu-user-static xz-utils ca-certificates && \
  mkdir -p /tmp/rootfs-buster && \
  debootstrap --arch=${ARCH} --variant=minbase buster /tmp/rootfs-buster ${DEBIAN_MIRROR} && \
  cd /tmp/rootfs-buster && tar -cJf /out/rootfs-buster-armhf.tar.xz . && echo 'Buster base tarball created'"

echo "Building Debian Stretch (armhf) rootfs with Eclipse (eclipse 4.8 / Photon)..."
# Stretch is archived — use archive.debian.org and disable validity-checking in apt inside the chroot
docker run --rm -v "$OUTDIR:/out" --privileged debian:bookworm-slim bash -c "\
  apt-get update && apt-get install -y --no-install-recommends debootstrap qemu-user-static xz-utils ca-certificates gnupg && \
  mkdir -p /tmp/rootfs-stretch && \
  debootstrap --arch=${ARCH} --variant=minbase stretch /tmp/rootfs-stretch http://archive.debian.org/debian/ && \
  # copy qemu-user-static for second-stage chroot execution
  cp /usr/bin/qemu-arm-static /tmp/rootfs-stretch/usr/bin/ || true && \
  # configure apt to use archive.debian.org and allow expired metadata
  cat >/tmp/rootfs-stretch/etc/apt/apt.conf.d/99no-check <<'EOF'\nAcquire::Check-Valid-Until "0";\nEOF && \
  cat >/tmp/rootfs-stretch/etc/apt/sources.list <<'EOF'\ndeb http://archive.debian.org/debian stretch main contrib non-free\nEOF && \
  # install minimal GUI pieces and eclipse (this will pull Java and GUI deps); noninteractive
  chroot /tmp/rootfs-stretch /bin/bash -lc "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get -y --no-install-recommends install eclipse default-jre xfce4 tigervnc-standalone-server; apt-get clean; rm -rf /var/lib/apt/lists/*" && \
  # Create tarball of the full Stretch rootfs (this will be large)
  cd /tmp/rootfs-stretch && tar -cJf /out/eclipse-desktop-stretch-armhf.tar.xz . && echo 'Stretch eclipse tarball created'"

echo "Build complete. Artifacts in: $OUTDIR"
ls -lh "$OUTDIR"