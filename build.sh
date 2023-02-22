#!/bin/bash

set -e

chromium_dir="${chromium_dir:-/srv/chromium}"
root_dir=$(dirname "$(readlink -f "$0")")
if [ ! -d "$chromium_dir" ]; then
    chromium_dir=$root_dir
fi
date_time=$(date '+%Y%m%d%H%M%S')
chromium_version=$(head -n 1 "${root_dir}/bromite/CHANGELOG.md" | sed 's/# \(.*\)/\1/')
chromium_code=$(echo "$chromium_version" | tr -d '.' | cut -c5-)
clean=0
gsync=0
history=1
test=0
arch=""

usage() {
    echo "Usage:"
    echo "  $(basename $(readlink -nf $0)) [ options ]"
    echo
    echo "  Options:"
    echo "    -a <arch> Build specified arch"
    echo "    -c Clean"
    echo "    -h Show this message"
    echo "    -s Sync without history"
    echo
    exit 1
}

build() {
    echo ">> [$(date)] Head commit: $(git show -s --format=%s)"
    apks="ChromePublic SystemWebView TrichromeChrome32 TrichromeLibrary32 TrichromeWebView32 TrichromeChrome6432 TrichromeLibrary6432 TrichromeWebView6432"
    build_args="$(cat "${root_dir}"/build/browser.gn_args) target_cpu=\"${1}\" "

    if [ $1 '==' "x86" ] || [ $1 '==' "x64" ]; then
        build_args+=' is_cfi=false'
        build_args+=' use_cfi_cast=false'
    else
        build_args+=' is_cfi=true'
        build_args+=' use_cfi_cast=true'
    fi

    code=$chromium_code
    if [ $1 '==' "arm" ]; then
        code+=00
    elif [ $1 '==' "arm64" ]; then
        code+=50
    elif [ $1 '==' "x86" ]; then
        code+=10
    elif [ $1 '==' "x64" ]; then
        code+=60
    fi
    build_args+=' android_default_version_name="'$chromium_version'"'
    build_args+=' android_default_version_code="'$code'"'

    # AOSP test-key signing for non docker builds
    if [ $test -eq 1 ]; then
        echo ">> [$(date)] Using AOSP test-key to sign"
        keystore_path="${root_dir}/build/platform.jks"
        build_args+=' android_keystore_path="'$keystore_path'"'
        build_args+=' android_keystore_name="platform"'
        build_args+=' android_keystore_password="platform"'
        build_args+=' trichrome_certdigest="c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8"'
    fi

    if [ $clean -eq 1 ] && [ -d "out/$1" ]; then
        rm -rf "out/$1"
    fi

    build_args+=' cc_wrapper="ccache"'

    echo ">> [$(date)] Building chromium $chromium_version for $1"
    gn gen "out/$1" --args="$build_args"
    if [ $1 '==' "x64" ] || [ $1 '==' "arm64" ]; then
        ninja -C out/$1 trichrome_webview_32_apk trichrome_chrome_32_apk trichrome_library_32_apk \
                trichrome_webview_64_32_apk trichrome_chrome_64_32_apk trichrome_library_64_32_apk \
                chrome_public_apk system_webview_apk
    elif [ $1 '==' "x86" ] || [ $1 '==' "arm" ]; then
        ninja -C out/$1 chrome_public_apk system_webview_apk
    fi

    for apk in $apks; do
        if [ -f "out/${1}/apks/$apk.apk" ]; then
            echo ">> [$(date)] Moving $apk for ${1} to output folder"
            if [[ "$apk.apk" == ChromePublic.apk ]]; then
                if [ "$1" = "x64" ]; then
                    mv "out/${1}/apks/ChromePublic.apk" "${root_dir}/apks/$date_time/x86_64/ChromePublic.apk"
                else
                    mv "out/${1}/apks/ChromePublic.apk" "${root_dir}/apks/$date_time/${1}/ChromePublic.apk"
                fi
            elif [[ "$apk.apk" == SystemWebView.apk ]]; then
                if [ "$1" = "x64" ]; then
                    mv "out/${1}/apks/SystemWebView.apk" "${root_dir}/apks/$date_time/x86_64/SystemWebView.apk"
                else
                    mv "out/${1}/apks/SystemWebView.apk" "${root_dir}/apks/$date_time/${1}/SystemWebView.apk"
                fi
            elif [[ "$apk.apk" == *6432.apk ]]; then
                if [ "$1" = "x64" ]; then
                    mv "out/${1}/apks/$apk.apk" "${root_dir}/apks/$date_time/x86_64/${apk::-4}.apk"
                elif [ "$1" = "arm64" ]; then
                    mv "out/${1}/apks/$apk.apk" "${root_dir}/apks/$date_time/arm64/${apk::-4}.apk"
                fi
            else
                if [ "$1" = "x64" ]; then
                    mv "out/${1}/apks/$apk.apk" "${root_dir}/apks/$date_time/x86/${apk::-2}.apk"
                elif [ "$1" = "arm64" ]; then
                    mv "out/${1}/apks/$apk.apk" "${root_dir}/apks/$date_time/arm/${apk::-2}.apk"
                fi
            fi
        fi
    done
}

setup_ccache() {
    echo ">> [$(date)] Settings up ccache"
    export USE_CCACHE=1
    export CCACHE_EXEC=$(command -v ccache)
    export PATH=$chromium_dir/src/third_party/llvm-build/Release+Asserts/bin:$PATH
    export CCACHE_CPP2=yes
    export CCACHE_SLOPPINESS=time_macros
    export CCACHE_DIR=$chromium_dir/.ccache
    ccache -M 200G
}

patch() {
    cd $chromium_dir/src
    echo ">> [$(date)] Applying bromite and /e/ patches"

    bromite_patches_list=$(cat "${root_dir}/bromite/build/bromite_patches_list.txt")
    for file in $bromite_patches_list; do
        git am -3 --ignore-whitespace "${root_dir}/bromite/build/patches/$file"
    done

    e_patches_list=$(cat "${root_dir}/build/e_patches_list.txt")
    for file in $e_patches_list; do
        git am -3 --ignore-whitespace "${root_dir}/build/patches/$file"
    done
}

sync() {
    echo ">> [$(date)] Syncing chromium $chromium_version"
    cd $chromium_dir
    cp ${root_dir}/.config_gclient $chromium_dir/.gclient
    if [ $history -eq 1 ]; then
        yes | gclient sync -D -R -r $chromium_version
    else
        yes | gclient sync --no-history -D -R -r $chromium_version
    fi
    patch
}

init_repo(){
    echo ">> [$(date)] Init chromium $chromium_version"
    cd $chromium_dir
    rm -rf .gclient*
    if [ $history -eq 1 ]; then
        fetch android
    else
        fetch --no-history android
    fi
}

while getopts ":a:chr:st" opt; do
    case $opt in
    a) arch="$OPTARG" ;;
    c) clean=1 ;;
    h) usage ;;
    s) gsync=1 && history=0 ;;
    t) test=1 ;;
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
    echo ">> [$(date)] Cleaning chromium source code"
    if [ -d "$chromium_dir/src" ]; then
        cd $chromium_dir/src
        git reset --hard && git clean -xfdf
    fi
fi

if [ ! -d "$chromium_dir/src" ]; then
    init_repo
    sync
fi

if [ $gsync -eq 1 ]; then
    if [ -d "$chromium_dir/src/.git/rebase-apply" ]; then
        rm -fr "$chromium_dir/src/.git/rebase-apply"
    fi
    find "$chromium_dir/src/.git" -name "*.lock" -delete
    if [ ! -z $(find $chromium_dir/src/.git -name "*.lock") ]; then
        rm -fr $chromium_dir/src
        init_repo
    fi
    sync
fi

mkdir -p "${root_dir}/apks/$date_time/x86_64" "${root_dir}/apks/$date_time/arm64" "${root_dir}/apks/$date_time/x86" "${root_dir}/apks/$date_time/arm"

cd $chromium_dir/src
. build/android/envsetup.sh
setup_ccache

if [ ! -z "$arch" ]; then
    build $arch
else
    build arm
    build arm64
    build x86
    build x64
fi

if [ -d "${root_dir}/apks" ]; then
    find "${root_dir}/apks" -empty -type d -delete
fi
