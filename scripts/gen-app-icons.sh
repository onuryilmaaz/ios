#!/bin/sh
# Uygulama ikonlarını RN kaynaklarının yerel kopyasından asset catalog'a kopyalar.
# İkonlar değişirse depo kökünden yeniden çalıştır: sh scripts/gen-app-icons.sh
# Ana ikon: Shared/mobile/assets/icon.png (Orman).
# (adlar RN appIcon.service / withSalahWidgets.js ile aynı).
set -e
cd "$(dirname "$0")/.."
SRC=Shared/mobile/assets
CAT=Salah/Resources/Assets.xcassets
rm -rf "$CAT"
mkdir -p "$CAT"
printf '{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n' > "$CAT/Contents.json"

iconset() { # $1 ad, $2 kaynak
  mkdir -p "$CAT/$1.appiconset"
  cp "$2" "$CAT/$1.appiconset/icon.png"
  cat > "$CAT/$1.appiconset/Contents.json" <<JSON
{
  "images" : [ { "filename" : "icon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
}
imageset() { # $1 ad, $2 kaynak (seçicideki küçük önizleme)
  mkdir -p "$CAT/$1.imageset"
  cp "$2" "$CAT/$1.imageset/thumb.png"
  cat > "$CAT/$1.imageset/Contents.json" <<JSON
{
  "images" : [ { "filename" : "thumb.png", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
}

iconset AppIcon "$SRC/icon.png"
iconset AppIconClassic "$SRC/app-icons/classic.png"
iconset AppIconNight "$SRC/app-icons/night.png"
iconset AppIconGold "$SRC/app-icons/gold.png"
for id in default classic night gold; do imageset "AppIconThumb-$id" "$SRC/app-icons/thumbs/$id.png"; done

# Açılış ekranı zemini (storyboard bu adla başvurur; Accent 900 #113C2F).
mkdir -p "$CAT/SalahLaunchBackground.colorset"
cat > "$CAT/SalahLaunchBackground.colorset/Contents.json" <<JSON
{
  "colors" : [ { "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "red" : "0x11", "green" : "0x3C", "blue" : "0x2F" } }, "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
echo "Asset catalog: $CAT"
