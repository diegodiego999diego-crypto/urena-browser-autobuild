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
ccache=1
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
  echo "    -C Disable ccache"
  echo
  exit 1
}

build() {
  echo ">> [$(date)] Head commit: $(git show -s --format=%s)"
  apks="ChromePublic SystemWebView"
  build_args="$(cat "${root_dir}"/build/vanilla.gn_args) target_cpu=\"${1}\" "

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

  if [ $ccache -eq 1 ]; then
    build_args+=' cc_wrapper="ccache"'
  fi

  echo ">> [$(date)] Using AOSP test-key for release build"
  keystore_path="${root_dir}/platform.jks"
  build_args+=' android_keystore_path="'$keystore_path'"'
  build_args+=' android_keystore_name="platform"'
  build_args+=' android_keystore_password="platform"'

  echo ">> [$(date)] Building chromium $chromium_version for $1"
  gn gen "out/$1" --fail-on-unused-args --args="$build_args"
  build_targets="chrome_public_apk system_webview_apk"

  ninja -C out/$1 $build_targets
  mkdir -p "${root_dir}/apks/${apk_arch}"

  for apk in $apks; do
    if [ -f "out/${1}/apks/$apk.apk" ]; then
      echo ">> [$(date)] Moving release $apk for ${apk_arch} to output folder"
      mv "out/${1}/apks/$apk.apk" "${root_dir}/apks/${apk_arch}/$(echo "$apk" | sed 's/[0-9]*//g').apk"
    fi
  done
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

setup_ccache() {
  echo ">> [$(date)] Setting up ccache config"
  export PATH=$chromium_dir/src/third_party/llvm-build/Release+Asserts/bin:$PATH
  export USE_CCACHE=1

  echo ">> [$(date)] Applying ccache configuration"
  ccache --set-config=max_size=75G \
    --set-config=compression_level=6 \
    --set-config=cache_dir="$chromium_dir/.ccache" \
    --set-config=base_dir="$chromium_dir/src" \
    --set-config=compiler_check=content \
    --set-config=hash_dir=false \
    --set-config=depend_mode=true \
    --set-config=sloppiness=time_macros

  echo ">> [$(date)] Cleaning unused cache files and statistics"
  ccache --evict-older-than 60d
  ccache -z

  echo ">> [$(date)] Recompressing existing cache entries"
  ccache --recompress 6

  export PATH="/usr/lib/ccache:$PATH"
}

while getopts ":a:cushC" opt; do
  case $opt in
  a) arch="$OPTARG" ;;
  c) clean=1 ;;
  C) ccache=0 ;;
  u) usage ;;
  s) gsync=1 ;;
  h) history=0 ;;
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

if [ $ccache -eq 1 ]; then
  setup_ccache
fi

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
fi

cd $chromium_dir/src
. build/android/envsetup.sh

if [ ! -z "$arch" ]; then
  build $arch
else
  build arm
  build arm64
  build x86
  build x64
fi

if [ $ccache -eq 1 ]; then
  ccache -s
fi
