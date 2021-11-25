#!/bin/bash -e

CHROMIUM_DIR="${CHROMIUM_DIR:-/srv/chromium}"
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

function init() {
    cd "${CHROMIUM_DIR}"
    if [ ! -f .gclient ]; then
        echo ">> [$(date)] Init project"
        fetch --nohooks android
    fi
    mkdir -p "${ROOT_DIR}/apks"
    clean
    cd "${CHROMIUM_DIR}/src"
}

function checkout() {
    if [ -z "${CHROMIUM_VERSION}" ] ; then
        CHROMIUM_VERSION=$(head -n 1 "${ROOT_DIR}/CHANGELOG.md" | sed 's/# \(.*\)/\1/')
        export CHROMIUM_VERSION
    fi
    
    echo ">> [$(date)] Use Chromium v${CHROMIUM_VERSION}"

    git fetch --tags
    git checkout "tags/${CHROMIUM_VERSION}"
}

function clean() {
    if [ -d "${CHROMIUM_DIR}/src" ]; then
        cd "${CHROMIUM_DIR}/src"
        git reset --hard && git clean -xfdf
    fi
}

function setup() {
    echo ">> [$(date)] Install dependencies"
    build/install-build-deps-android.sh
    gclient sync --with_branch_heads --with_tags
}

function patch() {
    echo ">> [$(date)] Apply Bromite and /e/ patches"
    mv "${ROOT_DIR}"/build/patches/e/* "${ROOT_DIR}"/build/patches/
    PATCHES_LIST=$(cat "${ROOT_DIR}/build/bromite_patches_list.txt" "${ROOT_DIR}/build/e_patches_list.txt")
    for file in $PATCHES_LIST; do
        echo " -> Apply $file"
        git apply "${ROOT_DIR}/build/patches/$file"
        echo " "
    done
    gclient runhooks
}

function build() {
    local out="out/${BUILDID}_${ARCH}"
    echo ">> [$(date)] Build for ${ARCH}"
    gn gen --args="$(cat "${ROOT_DIR}"/build/GN_ARGS) target_cpu=\"${ARCH}\" " "$out"
    autoninja -C "$out" chrome_public_apk system_webview_apk
    cp "$out/apks/ChromePublic.apk" "${ROOT_DIR}/apks/ChromePublic_$ARCH.apk"
    cp "$out/apks/SystemWebView.apk" "${ROOT_DIR}/apks/SystemWebView_$ARCH.apk"
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
