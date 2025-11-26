#!/bin/bash

DO_UNINSTALL=false
DO_CLEAR=false

while getopts "uc" opt; do
  case $opt in
  u) DO_UNINSTALL=true ;;
  c) DO_CLEAR=true ;;
  *)
    echo "Usage: $0 [-u] [-c]" >&2
    exit 1
    ;;
  esac
done

PACKAGES=(
  "foundation.e.browser"
  "com.android.webview"
  "org.chromium.trichromelibrary"
)

if [ "$DO_UNINSTALL" = true ]; then
  for pkg in "${PACKAGES[@]}"; do
    adb shell pm uninstall "$pkg"
  done
fi

if [ "$DO_CLEAR" = true ]; then
  for pkg in "${PACKAGES[@]}"; do
    adb shell pm clear "$pkg"
  done
fi

APK_DIR="apks/arm64"

if [ -f "$APK_DIR/TrichromeLibrary.apk" ] && \
   [ -f "$APK_DIR/TrichromeWebView.apk" ] && \
   [ -f "$APK_DIR/TrichromeChrome.apk" ]; then
  adb install -r $APK_DIR/TrichromeLibrary.apk
  adb install -r $APK_DIR/TrichromeWebView.apk
  adb install -r $APK_DIR/TrichromeChrome.apk
else
  adb install -r $APK_DIR/ChromePublic.apk
  adb install -r $APK_DIR/SystemWebView.apk
fi

echo "Done."
