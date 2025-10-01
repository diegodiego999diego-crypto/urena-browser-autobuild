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

adb install -r apks/arm64/TrichromeLibrary.apk
adb install -r apks/arm64/TrichromeWebView.apk
adb install -r apks/arm64/TrichromeChrome.apk

echo "Done."
