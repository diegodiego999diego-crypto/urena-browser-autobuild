#!/bin/bash

set -e

chromium_dir="${chromium_dir:-/srv/chromium}"
root_dir=$(dirname "$(readlink -f "$0")")
if [ ! -d "$chromium_dir" ]; then
    chromium_dir=$root_dir
fi
chromium_version=$(head -n 1 "${root_dir}/bromite/CHANGELOG.md" | sed 's/# \(.*\)/\1/')
clean=0
gsync=0
arch=""

usage() {
    echo "Usage:"
    echo "  $(basename $(readlink -nf $0)) [ options ]"
    echo
    echo "  Options:"
    echo "    -a <arch> Build specified arch"
    echo "    -c Clean"
    echo "    -h Show this message"
    echo "    -s Sync"
    echo
    exit 1
}

build() {
    mkdir -p "${root_dir}/apks/${1}"
    gn gen "out/$1" --args="$(cat "${root_dir}"/build/browser.gn_args) target_cpu=\"${1}\" "
    if [ "$1" = "arm" ] || [ "$1" = "x86" ]; then
        ninja -C out/$1 chrome_public_apk system_webview_apk
    elif [ "$1" = "arm64" ] || [ "$1" = "x64" ]; then
        ninja -C out/$1 trichrome_webview_64_32_apk trichrome_chrome_64_32_apk trichrome_library_64_32_apk
    fi
    apks="ChromePublic SystemWebView TrichromeChrome6432 TrichromeLibrary6432 TrichromeWebView6432"
    for apk in $apks; do
        if [ -f "out/${1}/apks/$apk.apk" ]; then
            cp "out/${1}/apks/$apk.apk" "${root_dir}/apks/${1}/$apk.apk"
        fi
    done
}

patch() {
    cd $chromium_dir/src
    echo ">> [$(date)] Apply Bromite and /e/ patches"

    bromite_patches_list=$(cat "${root_dir}/bromite/build/bromite_patches_list.txt")
    for file in $bromite_patches_list; do
        git am -3 --ignore-whitespace "${root_dir}/bromite/build/patches/$file"
    done

    e_patches_list=$(cat "${root_dir}/build/e_patches_list.txt")
    for file in $e_patches_list; do
        git am -3 --ignore-whitespace "${root_dir}/build/patches/$file"
    done
}

while getopts ":a:chr:s" opt; do
    case $opt in
    a) arch="$OPTARG" ;;
    c) clean=1 ;;
    h) usage ;;
    s) gsync=1 ;;
    :)
        echo "Option -$OPTARG requires an argument"
        echo
        usage
        ;;
    \?)
        echo "Invalid option:-$OPTARG"
        echo
        usage
        ;;
    esac
done
shift $((OPTIND - 1))

# Add depot_tools to PATH
if [ ! -d "$chromium_dir/depot_tools" ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$chromium_dir/depot_tools"
fi
export PATH="$chromium_dir/depot_tools:$PATH"

if [ $clean -eq 1 ]; then
    cd $chromium_dir/src
    git reset --hard && git clean -xfdf
    if [ -d out ]; then
        rm -rf out
    fi
fi

cd $chromium_dir

if [ ! -d src ]; then
    fetch android
    yes | gclient sync -D -R -r $chromium_version
    patch
fi

if [ $gsync -eq 1 ]; then
    find src -name index.lock -delete
    yes | gclient sync -D -R -r $chromium_version
    patch
fi

cd $chromium_dir/src
. build/android/envsetup.sh
. build/install-build-deps-android.sh

if [ ! -z "$arch" ]; then
    build $arch
else
    build arm
    build arm64
    build x86
    build x64
fi
