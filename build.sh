#!/bin/bash
# Compile Ondelette et produit build/Ondelette.app
# Usage : ./build.sh [--install]   (--install : installe dans /Applications et relance l'app)
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Compilation (release)…"
swift build -c release

APP="build/Ondelette.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Ondelette "$APP/Contents/MacOS/Ondelette"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Bundles de ressources SPM (modèles/config des dépendances)
for bundle in .build/release/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

# Identité Apple Development si disponible (signature stable → les
# autorisations Accessibilité/Micro survivent aux rebuilds), sinon ad hoc.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')
if [[ -n "$IDENTITY" ]]; then
    echo "▸ Signature ($IDENTITY)…"
    codesign --force --deep --sign "$IDENTITY" "$APP"
else
    echo "▸ Signature (ad hoc)…"
    codesign --force --deep --sign - "$APP"
fi
echo "✓ App prête : $APP"

if [[ "${1:-}" == "--install" ]]; then
    echo "▸ Installation dans /Applications…"
    pkill -x Ondelette 2>/dev/null && sleep 1 || true
    rm -rf /Applications/Ondelette.app
    cp -R "$APP" /Applications/Ondelette.app
    rm -rf "$APP" build
    open /Applications/Ondelette.app
    echo "✓ Ondelette installée et lancée depuis /Applications"
else
    echo "  Lancer avec : open $APP"
fi
