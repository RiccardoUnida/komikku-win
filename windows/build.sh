#!/usr/bin/env bash
# Build a portable Windows bundle of Komikku.
#
# Run from an MSYS2 **UCRT64** shell:   bash windows/build.sh
#
# Output:  _winbuild/Komikku/                       (portable folder)
#          _winbuild/Komikku-<version>-windows-x64.zip
#
# Environment variables (all optional):
#   RELAX_DEPS=1   drop the minimum-version checks of meson dependencies
#                  (use only if MSYS2 ships older GTK/libadwaita than Komikku asks for)
#   SKIP_DEPS=1    do not run pacman/pip (packages already installed)
#
# NOTE: WebKitGTK is not used. The upstream script scripts/remove_webview.py is
# applied to a copy of the sources, which removes the servers and trackers that
# need a web view (captcha / login flows).

set -euo pipefail

if [[ "${MSYSTEM:-}" != "UCRT64" ]]; then
    echo "error: run this script from an MSYS2 UCRT64 shell (MSYSTEM=${MSYSTEM:-unset})" >&2
    exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(dirname "$HERE")"
WORK="$SRC_DIR/_winbuild"
SRC="$WORK/src"
BUILD="$WORK/build"
BUNDLE="$WORK/Komikku"
PFX="$MSYSTEM_PREFIX"                 # /ucrt64
PKG="mingw-w64-ucrt-x86_64"

step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

###############################################################################
step "1/8  Dependencies"
###############################################################################
if [[ "${SKIP_DEPS:-0}" != "1" ]]; then
    pacman -S --needed --noconfirm \
        git \
        "$PKG-meson" "$PKG-ninja" "$PKG-pkgconf" "$PKG-gettext-tools" \
        "$PKG-glib2" "$PKG-gobject-introspection" \
        "$PKG-gtk4" "$PKG-libadwaita" "$PKG-gtksourceview5" "$PKG-libsoup3" \
        "$PKG-gdk-pixbuf2" "$PKG-librsvg" "$PKG-adwaita-icon-theme" \
        "$PKG-glib-networking" "$PKG-file" "$PKG-ca-certificates" \
        "$PKG-python" "$PKG-python-pip" "$PKG-python-gobject" "$PKG-python-cairo" \
        "$PKG-blueprint-compiler"

    # Optional: more image formats for GdkPixbuf (webp is very common in manga sites)
    for opt in webp-pixbuf-loader libheif libjxl; do
        if pacman -Si "$PKG-$opt" >/dev/null 2>&1; then
            pacman -S --needed --noconfirm "$PKG-$opt" || warn "could not install $PKG-$opt"
        else
            warn "package $PKG-$opt does not exist, skipped"
        fi
    done

    # Python modules: prefer the MSYS2 package (compiled modules need it), fall back to pip.
    # usage: py_dep <msys2 package suffix> <pip name>
    py_dep() {
        if pacman -Si "$PKG-python-$1" >/dev/null 2>&1; then
            pacman -S --needed --noconfirm "$PKG-python-$1"
        else
            echo "no MSYS2 package for python-$1, using pip ($2)"
            PIP_BREAK_SYSTEM_PACKAGES=1 python -m pip install --upgrade "$2"
        fi
    }
    py_dep pillow        pillow
    py_dep lxml          lxml
    py_dep cryptography  cryptography
    py_dep brotli        brotli
    py_dep requests      requests
    py_dep urllib3       urllib3
    py_dep beautifulsoup4 beautifulsoup4
    py_dep keyring       keyring
    py_dep dateparser    dateparser
    py_dep natsort       natsort
    py_dep emoji         emoji
    py_dep pytz          pytz
    py_dep unidecode     Unidecode
    py_dep colorlog      colorlog
    py_dep pyjwt         PyJWT
    py_dep pypdf         pypdf
    py_dep colorthief    colorthief
    py_dep piexif        piexif
    py_dep rarfile       rarfile
    py_dep pytesseract   pytesseract
    py_dep ebooklib      ebooklib

    # python-magic (ctypes wrapper around libmagic). Always from pip: the module
    # shipped with the MSYS2 'file' package has a different, incompatible API.
    PIP_BREAK_SYSTEM_PACKAGES=1 python -m pip install --upgrade python-magic
fi

PYVER="$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
echo "Python $PYVER"

###############################################################################
step "2/8  Prepare a patched copy of the sources"
###############################################################################
rm -rf "$WORK"
mkdir -p "$SRC"
tar -C "$SRC_DIR" --exclude=./_winbuild --exclude=./.git -cf - . | tar -C "$SRC" -xf -

VERSION="$(sed -n "s/^ *version: *'\([^']*\)'.*/\1/p" "$SRC/meson.build" | head -n1)"
echo "Komikku version: $VERSION"
echo "$VERSION" > "$WORK/version.txt"

(
    cd "$SRC"

    # No WebKitGTK on Windows: strip every WebView dependency (upstream-supported variant)
    python scripts/remove_webview.py

    # appstreamcli is only used to validate the metainfo file (a test): make it optional
    sed -i "s/find_program('appstreamcli')/find_program('appstreamcli', required: false)/" data/meson.build

    # Post-install helpers do not exist on Windows (or are redone by this script)
    sed -i \
        -e 's/gtk_update_icon_cache: true/gtk_update_icon_cache: false/' \
        -e 's/glib_compile_schemas: true/glib_compile_schemas: false/' \
        -e 's/update_desktop_database: true/update_desktop_database: false/' \
        meson.build

    if [[ "${RELAX_DEPS:-0}" == "1" ]]; then
        warn "RELAX_DEPS=1: minimum versions of GTK/libadwaita/... are not enforced"
        sed -i -E "s/(dependency\('[^']+'), version: '[^']*'\)/\1)/" data/meson.build
    fi
)

###############################################################################
step "3/8  Configure, compile and install with Meson"
###############################################################################
PREFIX_WIN="$(cygpath -m "$BUNDLE")"
meson setup "$BUILD" "$SRC" \
    --prefix="$PREFIX_WIN" \
    --bindir=bin --datadir=share --libdir=lib --localedir=share/locale \
    -Dprofile=default
meson compile -C "$BUILD"
meson install -C "$BUILD" --no-rebuild

SITE_DIR="$(dirname "$(find "$BUNDLE" -type d -name komikku -path '*site-packages*' | head -n1)")"
if [[ -z "$SITE_DIR" || "$SITE_DIR" == "." ]]; then
    echo "error: komikku python package was not installed into the bundle" >&2
    exit 1
fi
echo "komikku package installed in: $SITE_DIR"

###############################################################################
step "4/8  Python runtime"
###############################################################################
mkdir -p "$BUNDLE/bin" "$BUNDLE/lib"
cp -f "$PFX/bin/python.exe" "$BUNDLE/bin/python.exe"
if [[ -f "$PFX/bin/pythonw.exe" ]]; then
    cp -f "$PFX/bin/pythonw.exe" "$BUNDLE/bin/pythonw.exe"
else
    warn "pythonw.exe not found, falling back to python.exe (a console window will appear)"
    cp -f "$PFX/bin/python.exe" "$BUNDLE/bin/pythonw.exe"
fi

# standard library + site-packages (merged with what Meson installed)
mkdir -p "$BUNDLE/lib/python$PYVER"
tar -C "$PFX/lib" \
    --exclude='__pycache__' \
    --exclude="python$PYVER/test" \
    --exclude="python$PYVER/idlelib" \
    --exclude="python$PYVER/tkinter" \
    --exclude="python$PYVER/turtledemo" \
    --exclude="python$PYVER/ensurepip" \
    --exclude="python$PYVER/site-packages/pip" \
    --exclude="python$PYVER/site-packages/meson*" \
    --exclude="python$PYVER/site-packages/blueprintcompiler" \
    -cf - "python$PYVER" | tar -C "$BUNDLE/lib" -xf -

###############################################################################
step "5/8  GTK runtime data (typelibs, schemas, icons, loaders, certificates)"
###############################################################################
copy_dir() {   # copy_dir <relative dir under $PFX> [required]
    if [[ -d "$PFX/$1" ]]; then
        mkdir -p "$BUNDLE/$(dirname "$1")"
        cp -aL "$PFX/$1" "$BUNDLE/$(dirname "$1")/"
    elif [[ "${2:-}" == "required" ]]; then
        echo "error: $PFX/$1 not found" >&2
        exit 1
    else
        warn "$PFX/$1 not found, skipped"
    fi
}

copy_dir lib/girepository-1.0 required
copy_dir lib/gdk-pixbuf-2.0 required
copy_dir lib/gio
copy_dir lib/gtk-4.0
copy_dir share/gtksourceview-5
copy_dir share/mime
copy_dir etc/fonts
copy_dir share/icons/Adwaita

mkdir -p "$BUNDLE/share/icons/hicolor" "$BUNDLE/share/misc" "$BUNDLE/etc/ssl/certs"
[[ -f "$PFX/share/icons/hicolor/index.theme" ]] && cp -n "$PFX/share/icons/hicolor/index.theme" "$BUNDLE/share/icons/hicolor/"

# libmagic database
if [[ -f "$PFX/share/misc/magic.mgc" ]]; then
    cp -f "$PFX/share/misc/magic.mgc" "$BUNDLE/share/misc/"
else
    warn "magic.mgc not found: MIME detection will not work"
fi

# CA certificates for `requests`
CA_FOUND=""
for ca in "$PFX/etc/ssl/certs/ca-bundle.crt" "$PFX/ssl/certs/ca-bundle.crt" /usr/ssl/certs/ca-bundle.crt /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; do
    if [[ -f "$ca" ]]; then cp -f "$ca" "$BUNDLE/etc/ssl/certs/ca-bundle.crt"; CA_FOUND="$ca"; break; fi
done
[[ -n "$CA_FOUND" ]] && echo "CA bundle: $CA_FOUND" || warn "no CA bundle found: HTTPS requests will fail"

# GSettings schemas of GTK/libadwaita/GtkSourceView + Komikku, compiled together
mkdir -p "$BUNDLE/share/glib-2.0/schemas"
cp -n "$PFX"/share/glib-2.0/schemas/*.xml "$BUNDLE/share/glib-2.0/schemas/" 2>/dev/null || true
glib-compile-schemas "$BUNDLE/share/glib-2.0/schemas"

# Translations of the libraries (keep Komikku's own, already installed by Meson)
find "$PFX/share/locale" -type f \( -name 'gtk40.mo' -o -name 'libadwaita.mo' -o -name 'glib20.mo' -o -name 'gtksourceview-5.mo' -o -name 'gdk-pixbuf.mo' \) 2>/dev/null |
while read -r mo; do
    rel="${mo#"$PFX"/}"
    mkdir -p "$BUNDLE/$(dirname "$rel")"
    cp -f "$mo" "$BUNDLE/$rel"
done

###############################################################################
step "6/8  Native DLLs (dependency closure)"
###############################################################################
declare -A SEEN=()

copy_dll_closure() {
    local queue=("$@") f dep
    while ((${#queue[@]})); do
        f="${queue[0]}"
        queue=("${queue[@]:1}")
        while IFS= read -r dep; do
            [[ -z "$dep" || -n "${SEEN[$dep]:-}" ]] && continue
            SEEN[$dep]=1
            cp -n "$dep" "$BUNDLE/bin/"
            queue+=("$dep")
        done < <(ldd "$f" 2>/dev/null | awk -v p="$PFX/" '$2 == "=>" && index($3, p) == 1 { print $3 }')
    done
}

# Seeds: python, extension modules, plugins and every DLL named in a typelib
SEEDS=("$BUNDLE/bin/python.exe" "$BUNDLE/bin/pythonw.exe")
while IFS= read -r f; do SEEDS+=("$f"); done < <(find "$BUNDLE/lib" \( -name '*.pyd' -o -name '*.dll' \))

# helper tools needed at run time
for exe in gdk-pixbuf-query-loaders.exe; do
    if [[ -f "$PFX/bin/$exe" ]]; then cp -f "$PFX/bin/$exe" "$BUNDLE/bin/"; SEEDS+=("$BUNDLE/bin/$exe"); fi
done

while IFS= read -r name; do
    [[ -f "$PFX/bin/$name" ]] && SEEDS+=("$PFX/bin/$name")
done < <(python - "$BUNDLE/lib/girepository-1.0" <<'PY'
import pathlib, re, sys
names = set()
for tl in pathlib.Path(sys.argv[1]).glob('*.typelib'):
    names.update(m.decode() for m in re.findall(rb'[A-Za-z0-9_.+-]+\.dll', tl.read_bytes()))
print('\n'.join(sorted(names)))
PY
)

# libmagic (loaded by python-magic through ctypes, so not visible to ldd)
for f in "$PFX"/bin/libmagic-*.dll "$PFX"/bin/libgnutls-*.dll; do [[ -f "$f" ]] && SEEDS+=("$f"); done

# Seeds living in $PFX/bin must also be copied themselves
for f in "${SEEDS[@]}"; do
    if [[ "$f" == "$PFX/bin/"* && -z "${SEEN[$f]:-}" ]]; then SEEN[$f]=1; cp -n "$f" "$BUNDLE/bin/"; fi
done
copy_dll_closure "${SEEDS[@]}"
echo "$(find "$BUNDLE/bin" -name '*.dll' | wc -l) DLLs in bundle/bin"

###############################################################################
step "7/8  Launchers, icon and metadata"
###############################################################################
sed \
    -e "s|@APPID@|info.febvre.Komikku|g" \
    -e "s|@AUTHOR@|Valéry Febvre|g" \
    -e "s|@DESCRIPTION@|Discover and read manga|g" \
    -e "s|@GITREPO@|https://codeberg.org/valos/Komikku|g" \
    -e "s|@PROFILE@|default|g" \
    -e "s|@VERSION@|$VERSION|g" \
    "$HERE/launcher.pyw.in" > "$BUNDLE/komikku-launcher.pyw"

cp -f "$HERE/Komikku.vbs" "$HERE/Komikku-console.cmd" "$BUNDLE/"

# Application icon (best effort): SVG -> PNG -> ICO
ICON_SVG="$SRC/data/icons/info.febvre.Komikku.svg"
if command -v rsvg-convert >/dev/null 2>&1 && [[ -f "$ICON_SVG" ]]; then
    rsvg-convert -w 256 -h 256 -o "$WORK/komikku.png" "$ICON_SVG" &&
    python - "$WORK/komikku.png" "$BUNDLE/komikku.ico" <<'PY' || warn "icon conversion failed"
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2], sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
PY
else
    warn "rsvg-convert not found, no .ico generated"
fi

cp -f "$SRC/LICENSE" "$BUNDLE/" 2>/dev/null || true
cp -rf "$SRC/LICENSES" "$BUNDLE/" 2>/dev/null || true

###############################################################################
step "8/8  Zip"
###############################################################################
ZIP="$WORK/Komikku-$VERSION-windows-x64.zip"
(cd "$WORK" && python -m zipfile -c "$(basename "$ZIP")" Komikku)
echo
echo "Bundle : $BUNDLE"
echo "Zip    : $ZIP ($(du -sh "$ZIP" | cut -f1))"
echo "Next   : bash windows/selftest.sh   (checks the bundle in a clean environment)"
