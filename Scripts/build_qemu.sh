#!/bin/bash
# Run this ONCE on your dev Mac to build QEMU binaries to bundle into the app.
# Produces qemu-system-ppc, qemu-system-x86_64, and qemu-img.
set -e

echo "== Installing build deps via Homebrew =="
brew install pkg-config glib pixman ninja meson python3 gettext

echo "== Cloning QEMU source =="
cd /tmp
rm -rf qemu-build
git clone --depth 1 --branch stable-8.2 https://gitlab.com/qemu-project/qemu.git qemu-build
cd qemu-build

echo "== Configuring (PPC + x86_64 targets, HVF accel, Cocoa UI) =="
./configure \
  --target-list=ppc-softmmu,x86_64-softmmu \
  --enable-hvf \
  --enable-cocoa \
  --disable-docs \
  --prefix="$HOME/qemu-vintagemac-build"

echo "== Building (this takes a while) =="
make -j"$(sysctl -n hw.ncpu)"
make install

echo "== Done. Binaries are in: $HOME/qemu-vintagemac-build/bin =="
echo "Copy qemu-system-ppc, qemu-system-x86_64, qemu-img, and the qemu/share dir"
echo "into: RetroMultiOSE/Resources/qemu/"
echo ""
echo "If any of the compiled binaries link against Homebrew libraries at"
echo "runtime (check with otool -L), bundle those dependencies locally with:"
echo "  brew install dylibbundler"
echo "  dylibbundler -od -b -x ./qemu-system-ppc -d ./libs -p @executable_path/libs/"
echo "  dylibbundler -od -b -x ./qemu-system-x86_64 -d ./libs -p @executable_path/libs/"

# Basilisk II and SheepShaver are separate GPL projects, built similarly:
#   git clone https://github.com/kanjitalk755/macemu.git
# Build per their README (autotools) from src/Unix in each. On modern Xcode
# toolchains you will likely need to patch the generated Makefile's CC/CPP
# variables to force -std=gnu99 / -std=gnu++17 (they predate current C/C++
# standard defaults). Then bundle the resulting BasiliskII and SheepShaver
# binaries alongside the QEMU ones.
