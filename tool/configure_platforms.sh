#!/usr/bin/env bash
# Generates the ios/ and android/ folders with `flutter create` and applies MOM Wealth's settings:
# bundle IDs, app name, the momwealth:// link used to return from Squad checkout, minimum OS versions,
# app icons and splash screen. Safe to re-run: it only creates folders that don't exist yet, then
# (re)applies the settings.
set -euo pipefail
cd "$(dirname "$0")/.."

IOS_BUNDLE_ID="com.momrehoboth.momwealth"
ANDROID_APP_ID="com.mycompany.momwealth"   # matches the Android app already registered in Firebase
APP_NAME="MOM Wealth"

if [ ! -d ios ] || [ ! -d android ]; then
  flutter create --org com.momrehoboth --project-name momwealth --platforms ios,android --no-pub .
  rm -f test/widget_test.dart
fi

python3 - "$IOS_BUNDLE_ID" "$ANDROID_APP_ID" "$APP_NAME" <<'PY'
import re, sys, pathlib
ios_id, android_id, name = sys.argv[1:4]

# ---- iOS: Info.plist
p = pathlib.Path("ios/Runner/Info.plist"); s = p.read_text()
def set_key(s, key, value_xml):
    if f"<key>{key}</key>" in s:
        return re.sub(rf"<key>{key}</key>\s*<[^>]+>[^<]*</[^>]+>|<key>{key}</key>\s*<(true|false)/>", f"<key>{key}</key>\n\t{value_xml}", s, count=1)
    return s.replace("</dict>\n</plist>", f"\t<key>{key}</key>\n\t{value_xml}\n</dict>\n</plist>")
s = set_key(s, "CFBundleDisplayName", f"<string>{name}</string>")
s = set_key(s, "CFBundleName", f"<string>{name}</string>")
s = set_key(s, "ITSAppUsesNonExemptEncryption", "<false/>")
if "CFBundleURLTypes" not in s:
    s = s.replace("</dict>\n</plist>", """\t<key>CFBundleURLTypes</key>
\t<array>
\t\t<dict>
\t\t\t<key>CFBundleURLName</key>
\t\t\t<string>payment-return</string>
\t\t\t<key>CFBundleURLSchemes</key>
\t\t\t<array>
\t\t\t\t<string>momwealth</string>
\t\t\t</array>
\t\t</dict>
\t</array>
</dict>
</plist>""")
if "UISupportedInterfaceOrientations" in s:
    s = re.sub(r"<key>UISupportedInterfaceOrientations</key>\s*<array>.*?</array>",
               "<key>UISupportedInterfaceOrientations</key>\n\t<array>\n\t\t<string>UIInterfaceOrientationPortrait</string>\n\t</array>", s, count=1, flags=re.S)
p.write_text(s)

# ---- iOS: bundle ID and minimum iOS 15 (Firebase requirement)
p = pathlib.Path("ios/Runner.xcodeproj/project.pbxproj"); s = p.read_text()
s = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = [^;]*\.momwealth;", f"PRODUCT_BUNDLE_IDENTIFIER = {ios_id};", s)
s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", s)
p.write_text(s)
pf = pathlib.Path("ios/Podfile")
if pf.exists():
    t = pf.read_text()
    t = re.sub(r"^#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.0'", t, flags=re.M)
    pf.write_text(t)

# ---- Android: application ID, minSdk, app name, momwealth:// link, Custom Tabs visibility
for g in ["android/app/build.gradle.kts", "android/app/build.gradle"]:
    p = pathlib.Path(g)
    if not p.exists():
        continue
    s = p.read_text()
    s = re.sub(r'applicationId\s*=?\s*"[^"]+"', f'applicationId = "{android_id}"' if g.endswith(".kts") else f'applicationId "{android_id}"', s)
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", s)
    s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", s)
    p.write_text(s)
p = pathlib.Path("android/app/src/main/AndroidManifest.xml"); s = p.read_text()
s = re.sub(r'android:label="[^"]*"', f'android:label="{name}"', s, count=1)
if "android:scheme=\"momwealth\"" not in s:
    s = s.replace("</activity>", """    <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="momwealth" android:host="payment" />
            </intent-filter>
        </activity>""", 1)
if "CustomTabsService" not in s:
    if "<queries>" in s:
        s = s.replace("<queries>", """<queries>
        <intent>
            <action android:name="android.support.customtabs.action.CustomTabsService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>""", 1)
    else:
        s = s.replace("</manifest>", """    <queries>
        <intent>
            <action android:name="android.support.customtabs.action.CustomTabsService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
    </queries>
</manifest>""")
if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
p.write_text(s)
# Android lint crashes inside the firebase_core plugin on current Gradle/Kotlin (a tooling bug, not
# our code). Release builds run "lintVital" checks by default, so skip them for all modules.
for g in ["android/build.gradle.kts", "android/build.gradle"]:
    p = pathlib.Path(g)
    if p.exists() and "lintVital" not in p.read_text():
        p.write_text(p.read_text().rstrip() + """

subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}
""")
print("platform settings applied")
PY

flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
