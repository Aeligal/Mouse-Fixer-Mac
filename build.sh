#!/bin/zsh
# Builds ~/Applications/Mouse Fixer.app (ad-hoc signed)
set -e
cd "$(dirname "$0")"
APP="$HOME/Applications/Mouse Fixer.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/MouseFixer"
mkdir -p "$APP/Contents/Resources"
python3 l10n/gen.py >/dev/null && for d in l10n/*.lproj; do cp -R "$d" "$APP/Contents/Resources/"; done
mkdir -p "$APP/Contents/Resources/en.lproj" && : > "$APP/Contents/Resources/en.lproj/Localizable.strings"
swiftc -O icon/make_icon.swift -o icon/make_icon && rm -rf icon/AppIcon.iconset && icon/make_icon icon/AppIcon.iconset
iconutil -c icns icon/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns" && rm icon/make_icon
cat > "$APP/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MouseFixer</string>
<key>CFBundleIdentifier</key><string>local.mousefixer</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>de</string><string>fr</string><string>es</string><string>pt-BR</string><string>ja</string><string>zh-Hans</string><string>cs</string><string>ko</string><string>nb</string><string>ru</string><string>tr</string><string>uk</string><string>vi</string><string>zh-Hant</string><string>zh-HK</string></array>
<key>CFBundleName</key><string>Mouse Fixer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
P
codesign --force --sign "Mouse Fixer Dev" "$APP" # stable self-signed identity keeps the Accessibility grant across rebuilds
echo "built $APP"
