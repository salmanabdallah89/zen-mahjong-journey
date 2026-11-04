#!/usr/bin/env bash
# Builds addons/zen_play_billing/bin/zen_play_billing.aar from src/ (no Gradle project needed).
# Needs: JDK 17, the Android SDK, the installed Godot Android build template (android/build)
# and Play Billing 8.0.0 in the Gradle cache (any Gradle export with the plugin enabled fetches it).
# Run from the project root:  bash android_plugins/play_billing/build.sh
set -euo pipefail

JDK="${JDK:-/c/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot/bin}"
SDK="${ANDROID_SDK:-/c/Users/$USERNAME/AppData/Local/Android/Sdk}"
CACHE="${GRADLE_CACHE:-$HOME/.gradle/caches/modules-2/files-2.1}"
HERE="android_plugins/play_billing"
OUT="addons/zen_play_billing/bin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ANDROID_JAR="$SDK/platforms/android-36/android.jar"
aar_classes() {  # group/name/version -> classes.jar extracted into $WORK/<name>.jar
	local aar
	aar="$(find "$CACHE/$1/$2/$3" -name "*.aar" | head -1)"
	unzip -p "$aar" classes.jar > "$WORK/$2.jar"
	echo "$WORK/$2.jar"
}
unzip -p android/build/libs/release/godot-lib.template_release.aar classes.jar > "$WORK/godot.jar"
CP="$ANDROID_JAR:$WORK/godot.jar:$(aar_classes com.android.billingclient billing 8.0.0)"

mkdir -p "$WORK/classes" "$WORK/aar"
"$JDK/javac.exe" --release 17 -nowarn -cp "$(cygpath -wp "$CP")" \
	-d "$WORK/classes" "$HERE"/src/org/zenmahjong/playbilling/*.java
(cd "$WORK/classes" && "$JDK/jar.exe" cf ../aar/classes.jar .)
cp "$HERE/AndroidManifest.xml" "$WORK/aar/"
: > "$WORK/aar/R.txt"
mkdir -p "$OUT"
rm -f "$OUT/zen_play_billing.aar"
(cd "$WORK/aar" && "$JDK/jar.exe" cfM "$OLDPWD/$OUT/zen_play_billing.aar" AndroidManifest.xml classes.jar R.txt)
echo "built $OUT/zen_play_billing.aar"
