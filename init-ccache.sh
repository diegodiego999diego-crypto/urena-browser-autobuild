#!/usr/bin/env bash

chromium_dir="${CHROMIUM_DIR}"
root_dir=$(dirname "$(readlink -f "$0")")
if [ ! -d "$chromium_dir" ]; then
  chromium_dir=$root_dir
fi

echo ">> [$(date)] Setting up ccache config"
export PATH=$chromium_dir/src/third_party/llvm-build/Release+Asserts/bin:$PATH
export CCACHE_DIR=$chromium_dir/.ccache
export USE_CCACHE=1

echo ">> [$(date)] Applying ccache configuration"
ccache --set-config=max_size=200G \
  --set-config=compression_level=6 \
  --set-config=sloppiness=time_macros

echo ">> [$(date)] Cleaning unused cache files and statistics"
ccache --evict-older-than 30d
ccache -c
ccache -z

echo ">> [$(date)] Recompressing existing cache entries"
ccache --recompress 6

export PATH="/usr/lib/ccache:$PATH"
