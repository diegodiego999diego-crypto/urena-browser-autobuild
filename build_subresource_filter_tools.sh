#!/usr/bin/env bash

set -e

chromium_dir="${CHROMIUM_DIR}"
root_dir=$(dirname "$(readlink -f "$0")")
if [ ! -d "$chromium_dir" ]; then
  chromium_dir=$root_dir
fi

build() {
  echo ">> [$(date)] Building chromium subresource_filter_tools"
  mkdir -p "${root_dir}/bin"
  build_args=$(cat "${root_dir}"/build/filters.gn_args)
  build_args+=' cc_wrapper="ccache"'
  gn gen out/x64 --args="$build_args"
  autoninja -C out/x64 subresource_filter_tools
  if [ -f "out/x64/ruleset_converter" ]; then
    cp -r out/x64/ruleset_converter ${root_dir}/bin/ruleset_converter
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

export PATH="$chromium_dir/depot_tools:$PATH"

cd $chromium_dir/src
. build/android/envsetup.sh
setup_ccache
build
