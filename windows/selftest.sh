#!/usr/bin/env bash
# Run the bundle in a CLEAN environment (no MSYS2 on PATH) to prove it is self-contained.
# Run from an MSYS2 shell after windows/build.sh:   bash windows/selftest.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE="$(dirname "$HERE")/_winbuild/Komikku"
[[ -d "$BUNDLE" ]] || { echo "bundle not found: $BUNDLE (run windows/build.sh first)"; exit 2; }

ROOT_WIN="$(cygpath -w "$BUNDLE")"
SYSROOT="${SYSTEMROOT:-C:\\Windows}"

env -i \
    SYSTEMROOT="$SYSROOT" WINDIR="$SYSROOT" \
    LOCALAPPDATA="${LOCALAPPDATA:-$(cygpath -w "$HOME")}" \
    TEMP="${TEMP:-$(cygpath -w /tmp)}" TMP="${TEMP:-$(cygpath -w /tmp)}" \
    PATH="$(cygpath -u "$SYSROOT")/System32" \
    PYTHONHOME="$ROOT_WIN" \
    "$BUNDLE/bin/python.exe" "$BUNDLE/komikku-launcher.pyw" --selftest
