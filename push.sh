#!/bin/bash

adb shell pm uninstall foundation.e.browser
adb shell pm uninstall com.android.webview
adb shell pm uninstall org.chromium.trichromelibrary

adb shell pm clear foundation.e.browser
adb shell pm clear com.android.webview
adb shell pm clear org.chromium.trichromelibrary

adb install -r apks/arm64/TrichromeLibrary.apk
adb install -r apks/arm64/TrichromeWebView.apk
adb install -r apks/arm64/TrichromeChrome.apk
