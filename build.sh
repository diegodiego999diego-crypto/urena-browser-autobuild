#!/bin/bash -e

CHROMIUM_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ROOT_DIR=$(dirname "$(readlink -f "$0")")
BUILDID="${CI_JOB_ID:-$(date +%s)}"
ARCH=arm

function usage() {
    cat << EOT
  usage $0 [-hac]

  OPTIONS
    -h show this usage
    -a target build archictecture (default: arm)
    -c clean chromium repository
EOT
}

function clean() {
    if [ -d "${CHROMIUM_DIR}/src" ]; then
        cd "${CHROMIUM_DIR}/src"
        git reset --hard && git clean -xfdf
    fi
}

function init() {
    cd "${CHROMIUM_DIR}"
    if [ ! -f .gclient ]; then
        echo ">> [$(date)] Init project"
        fetch --nohooks android
    else
        gclient sync -D
    fi
    mkdir -p "${ROOT_DIR}/apks/${ARCH}"
    clean
    cd "${CHROMIUM_DIR}/src"
}

function checkout() {
    if [ -z "${CHROMIUM_VERSION}" ] ; then
        CHROMIUM_VERSION=$(head -n 1 "${ROOT_DIR}/bromite/CHANGELOG.md" | sed 's/# \(.*\)/\1/')
        export CHROMIUM_VERSION
    fi

    echo ">> [$(date)] Use Chromium v${CHROMIUM_VERSION}"

    git fetch https://chromium.googlesource.com/chromium/src ${CHROMIUM_VERSION}
    git checkout FETCH_HEAD
}

function setup() {
    echo ">> [$(date)] Install dependencies"
    build/install-build-deps-android.sh
    gclient sync -D
    gclient runhooks
}

function patch() {
    echo ">> [$(date)] Apply Bromite and /e/ patches"
    git config --local user.name "John Doe"
    git config --local user.email "johndoe@example.com"

    BROMITE_PATCHES_LIST=$(cat "${ROOT_DIR}/bromite/build/bromite_patches_list.txt")
    for file in $BROMITE_PATCHES_LIST; do
        echo " -> Applying $file"
        git am -3 --ignore-whitespace "${ROOT_DIR}/bromite/build/patches/$file"
    done

    E_PATCHES_LIST=$(cat "${ROOT_DIR}/build/e_patches_list.txt")
    for file in $E_PATCHES_LIST; do
        echo " -> Applying $file"
        git am -3 --ignore-whitespace "${ROOT_DIR}/build/patches/$file"
    done

    git config --local --unset user.name
    git config --local --unset user.email
}

function build() {
    local out="out/${BUILDID}_${ARCH}"
    echo ">> [$(date)] Build for ${ARCH}"
    gn gen --args="$(cat "${ROOT_DIR}"/build/browser.gn_args) target_cpu=\"${ARCH}\" " "$out"
    if [ "$ARCH" = "arm" ] || [ "$ARCH" = "x86" ]; then
        autoninja -C "$out" trichrome_webview_apk trichrome_chrome_apk trichrome_library_apk
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "x64" ]; then
        autoninja -C "$out" trichrome_webview_64_32_apk trichrome_chrome_64_32_apk trichrome_library_64_32_apk
    fi
    APKS="TrichromeChrome TrichromeLibrary TrichromeWebView TrichromeChrome6432 TrichromeLibrary6432 TrichromeWebView6432"
    for APK in $APKS; do
        if [ -f "$out/apks/$APK.apk" ]; then
            cp "$out/apks/$APK.apk" "${ROOT_DIR}/apks/${ARCH}/$APK.apk"
        fi
    done
}

while getopts "ha:c" option; do
    case $option in
        a)
          ARCH="$OPTARG"
          ;;
        c)
          clean
          exit 0
          ;;
        \?)
          echo "wrong option."
          usage
          exit 1
          ;;
        h)
          usage
          exit 0
          ;;
    esac
done
shift $((OPTIND - 1))

init
checkout
setup
patch
build
