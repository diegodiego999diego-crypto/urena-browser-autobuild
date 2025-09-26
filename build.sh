#!/usr/bin/env bash

set -e

chromium_dir="${CHROMIUM_DIR}"
root_dir=$(dirname "$(readlink -f "$0")")
if [ ! -d "$chromium_dir" ]; then
    chromium_dir=$root_dir
fi
chromium_version=$(grep 'chromium_version' versions.txt | awk -F'"' '{print $2}')
chromium_code=$(echo "${chromium_version}" | tr -d '.' | cut -c1-8)
chromium_url=https://github.com/chromium/chromium.git
clean=0
gsync=0
history=1
trichrome=0
patchonly=0
arch=""

usage() {
    echo "Usage:"
    echo "  $(basename $(readlink -nf $0)) [ options ]"
    echo
    echo "  Options:"
    echo "    -a <arch> Build specified arch"
    echo "    -c Clean"
    echo "    -u Show this message"
    echo "    -s Sync source"
    echo "    -h Sync without history"
    echo "    -p Apply patches - Only after synced"
    echo "    -t Build trichrome chromium, webview and library"
    echo
    exit 1
}

build() {
    echo ">> [$(date)] Head commit: $(git show -s --format=%s)"
    apks="TrichromeChrome TrichromeLibrary TrichromeWebView TrichromeChrome6432 \
        TrichromeLibrary6432 TrichromeWebView6432 ChromePublic SystemWebView"
    build_args="$(cat "${root_dir}"/build/browser.gn_args) target_cpu=\"${1}\" "

    apk_arch=${1}
    build_args+=' android_default_version_name="'$chromium_version'"'
    build_args+=' android_default_version_code="'$chromium_code'"'

    if [ $clean -eq 1 ]; then
        if [ -d "out/$1" ]; then
            rm -rf "out/$1"
        fi
        if [ -d "${root_dir}/apks/${apk_arch}" ]; then
            rm -rf "${root_dir}/apks/${apk_arch}"
        fi
    fi

    build_args+=' cc_wrapper="ccache"'

    echo ">> [$(date)] Using AOSP test-key for release build"
    keystore_path="${root_dir}/platform.jks"
    build_args+=' android_keystore_path="'$keystore_path'"'
    build_args+=' android_keystore_name="platform"'
    build_args+=' android_keystore_password="platform"'
    build_args+=' trichrome_certdigest="c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8"'

    echo ">> [$(date)] Building chromium $chromium_version for $1"
    gn gen "out/$1" --fail-on-unused-args --args="$build_args"
    if [[ $trichrome -eq 0 ]]; then
        build_targets="chrome_public_apk system_webview_apk"
    elif [ $1 '==' "x64" ] || [ $1 '==' "arm64" ]; then
        build_targets="trichrome_webview_64_32_apk trichrome_chrome_64_32_apk trichrome_library_64_32_apk"
    else
        build_targets="trichrome_webview_apk trichrome_chrome_apk trichrome_library_apk"
    fi

    ninja -C out/$1 $build_targets
    mkdir -p "${root_dir}/apks/${apk_arch}"

    for apk in $apks; do
        if [ -f "out/${1}/apks/$apk.apk" ]; then
            echo ">> [$(date)] Moving release $apk for ${apk_arch} to output folder"
            mv "out/${1}/apks/$apk.apk" "${root_dir}/apks/${apk_arch}/$(echo "$apk" | sed 's/[0-9]*//g').apk"
        fi
    done

    if [ $1 '==' "x64" ]; then
        echo ">> [$(date)] Building chromium subresource_filter_tools"
        mkdir -p "${root_dir}/bin"
        build_args=$(cat "${root_dir}"/build/filters.gn_args)
        build_args+=' cc_wrapper="ccache"'
        gn gen out/${1} --args="$build_args"
        autoninja -C out/${1} subresource_filter_tools
        if [ -f "out/${1}/ruleset_converter" ]; then
            cp -r out/${1}/ruleset_converter ${root_dir}/bin/ruleset_converter
        fi
    fi
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
    echo ">> [$(date)] Applying cromite patches"

    cromite_patches_list=$(cat "${root_dir}/build/cromite_patches_list.txt")
    for file in $cromite_patches_list; do
        git am -C0 -3 --ignore-whitespace "${root_dir}/build/cromite_patches/$file"
    done

    echo ">> [$(date)] Applying /e/ patches"

    e_patches_list=$(cat "${root_dir}/build/e_patches_list.txt")
    for file in $e_patches_list; do
        git am -C0 -3 --ignore-whitespace "${root_dir}/build/e_patches/$file"
    done

    echo ">> [$(date)] Applying third party patches"

    while read dir patch; do
        [ -z "$dir" ] && continue  # skip empty lines
        cd $chromium_dir/src/third_party/$dir
        git am -C0 -3 --ignore-whitespace "${root_dir}/build/third_party/$patch"
        cd $chromium_dir/src
    done < "${root_dir}/build/third_party_patches_list.txt"

    # Rename Chrome to Browser
    rename

    # domain_substitution from ungoogled-chromium
    domain_substitution
}

rename() {
    cd $chromium_dir/src

    replacements=(
        "Chrome browser=Browser"
        "Chrome=Browser"
        "Bromite=Browser"
        "Cromite=Browser"
        "Google Password Manager=Password Manager"
    )

    for replacement in "${replacements[@]}"; do
        replaced_string=${replacement%%=*}
        replacement_string=${replacement#*=}

        find . -type f -not -name 'foundation_e.grdp' -name '*.grd*' | while read -r filename; do
            sed -i "s/\b${replaced_string}\b/${replacement_string}/g" "$filename"
        done
        find . -type f -name '*.xtb' | while read -r filename; do
            sed -i "s/\b${replaced_string}\b/${replacement_string}/g" "$filename"
        done
    done

    git add .
    git commit -m "Browser: Replace Chrome with Browser"
}

domain_substitution() {
    cd "${root_dir}/domain_substitution"
    python3 domain_substitution.py apply -r domain_regex.list -f domain_substitution.list $chromium_dir/src
    cd $chromium_dir/src
    git add .
    git commit -m "Browser: Automated domain substitution"
}

sync() {
    echo ">> [$(date)] Syncing chromium $chromium_version"
    cd $chromium_dir
    gclient_config
    if [ -d "$chromium_dir/src" ]; then
        cd $chromium_dir/src
        git fetch origin refs/tags/$chromium_version
        if [ $clean -eq 1 ]; then
            git checkout main
            git reset --hard FETCH_HEAD
        else
            git reset --hard $chromium_commit_hash
        fi
    fi
    if [ $history -eq 1 ]; then
        gclient sync -D --nohooks -R --force
    else
        gclient sync --no-history -D --nohooks -R --force
    fi
    gclient runhooks
    patch
}

gclient_config() {
    cat <<EOF >"$chromium_dir/.gclient"
solutions = [{
    "url": "$chromium_url@$chromium_commit_hash",
    "managed": False,
    "name": "src",
    "deps_file": 'DEPS',
    "custom_deps": {},
    "custom_vars": {
        "checkout_android_prebuilts_build_tools": True,
        "checkout_telemetry_dependencies": False,
        "checkout_pgo_profiles": True,
    }
}]

target_os = ["android"]
EOF
}

init_repo() {
    echo ">> [$(date)] Init chromium $chromium_version"
    cd $chromium_dir
    rm -rf .gclient*
    if [ $history -eq 1 ]; then
        fetch android
    else
        fetch --no-history android
    fi
}

while getopts ":a:cur:shpt" opt; do
    case $opt in
    a) arch="$OPTARG" ;;
    c) clean=1 ;;
    u) usage ;;
    s) gsync=1 ;;
    h) history=0 ;;
    p) patchonly=1 ;;
    t) trichrome=1 ;;
    :)
        echo "Option -$OPTARG requires an argument"
        echo
        usage
        ;;
    \?)
        echo "Invalid option: -$OPTARG"
        echo
        usage
        ;;
    esac
done
shift $((OPTIND - 1))

# Add depot_tools to PATH
if [ ! -d "$chromium_dir/depot_tools" ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$chromium_dir/depot_tools"
else
    cd $chromium_dir/depot_tools
    git fetch https://chromium.googlesource.com/chromium/tools/depot_tools.git main
    git reset --hard FETCH_HEAD
    cd $chromium_dir
fi
export PATH="$chromium_dir/depot_tools:$PATH"

chromium_commit_hash=$(git ls-remote --refs $chromium_url refs/tags/$chromium_version | awk '{print $1}')

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
    cd $chromium_dir/src
    # Check if a rebase is in progress
    if [ -d "$(git rev-parse --git-dir)/rebase-apply" ] || [ -d "$(git rev-parse --git-dir)/rebase-merge" ]; then
        git am --skip 2>/dev/null || true
        git rebase --abort 2>/dev/null || true
        echo ">> [$(date)] Rebase aborted."
    fi
    find ".git" -name "*.lock" -delete
    if [ ! -z $(find .git -name "*.lock") ]; then
        echo ">> [$(date)] Re-init chromium."
        cd ${root_dir}
        rm -fr $chromium_dir/src
        init_repo
    fi
    sync
elif [ $patchonly -eq 1 ]; then
    cd $chromium_dir/src
    git fetch origin refs/tags/$chromium_version
    git checkout main
    git reset --hard FETCH_HEAD
    patch
fi

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
