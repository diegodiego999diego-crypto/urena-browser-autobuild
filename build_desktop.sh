#!/usr/bin/env bash

set -e

chromium_dir="${CHROMIUM_DIR}"
root_dir=$(dirname "$(readlink -f "$0")")
if [ ! -d "$chromium_dir" ]; then
  chromium_dir=$root_dir
fi
chromium_version=$(grep 'chromium_version' versions.txt | awk -F'"' '{print $2}')
chromium_url=https://github.com/chromium/chromium.git
clean=0
gsync=0
history=1
patchonly=0
arch="x64"
target_os="linux"

usage() {
  echo "Usage:"
  echo "  $(basename "$(readlink -nf "$0")") [ options ]"
  echo
  echo "  Options:"
  echo "    -a <arch> Build specified arch (default: x64)"
  echo "    -t <target> Build target OS: linux or windows (default: linux)"
  echo "    -c Clean"
  echo "    -u Show this message"
  echo "    -s Sync source"
  echo "    -h Sync without history"
  echo "    -p Apply patches - Only after synced"
  echo
  exit 1
}

normalize_target_os() {
  case "$1" in
  linux)
    echo "linux"
    ;;
  windows | win)
    echo "win"
    ;;
  *)
    echo "Unsupported target OS: $1"
    usage
    ;;
  esac
}

build_desktop() {
  echo ">> [$(date)] Head commit: $(git show -s --format=%s)"

  output_dir="out/${target_os}-${arch}"
  artifact_dir="${root_dir}/bin/${target_os}-${arch}"
  build_args="$(cat "${root_dir}"/build/desktop.gn_args) target_cpu=\"${arch}\" target_os=\"${target_os}\" "

  if [ $clean -eq 1 ]; then
    if [ -d "$output_dir" ]; then
      rm -rf "$output_dir"
    fi
    if [ -d "$artifact_dir" ]; then
      rm -rf "$artifact_dir"
    fi
  fi

  build_args+=' cc_wrapper="ccache"'

  echo ">> [$(date)] Building chromium ${chromium_version} for ${target_os}/${arch}"
  gn gen "$output_dir" --fail-on-unused-args --args="$build_args"
  autoninja -C "$output_dir" chrome

  mkdir -p "$artifact_dir"
  if [ "$target_os" = "win" ]; then
    if [ -f "${output_dir}/chrome.exe" ]; then
      cp "${output_dir}/chrome.exe" "$artifact_dir/chrome.exe"
    else
      echo "chrome.exe not found in ${output_dir}"
      exit 1
    fi
  else
    if [ -f "${output_dir}/chrome" ]; then
      cp "${output_dir}/chrome" "$artifact_dir/chrome"
    else
      echo "chrome not found in ${output_dir}"
      exit 1
    fi
  fi
}

patch() {
  cd "$chromium_dir/src"
  echo ">> [$(date)] Applying cromite patches"

  cromite_patches_list=$(cat "${root_dir}/build/cromite_patches_list.txt")
  cromite_patch_dir="${root_dir}/build/cromite/build/patches"
  if [ ! -d "${cromite_patch_dir}" ]; then
    echo "Cromite patches directory not found at ${cromite_patch_dir}."
    echo "Ensure the cromite submodule is initialized (run ./update_cromite_patches.sh)."
    exit 1
  fi
  for file in $cromite_patches_list; do
    patch_path="${cromite_patch_dir}/$file"
    if [ ! -f "${patch_path}" ]; then
      echo "Patch ${patch_path} missing."
      exit 1
    fi
    git am -C0 -3 --ignore-whitespace "${patch_path}"
  done

  echo ">> [$(date)] Applying /e/ patches"

  e_patches_list=$(cat "${root_dir}/build/e_patches_list.txt")
  for file in $e_patches_list; do
    git am -C0 -3 --ignore-whitespace "${root_dir}/build/e_patches/$file"
  done

  echo ">> [$(date)] Applying third party patches"

  while read -r dir patch_file; do
    [ -z "$dir" ] && continue
    cd "$chromium_dir/src/third_party/$dir"
    git am -C0 -3 --ignore-whitespace "${root_dir}/build/third_party/$patch_file"
    cd "$chromium_dir/src"
  done <"${root_dir}/build/third_party_patches_list.txt"

  rename
  domain_substitution
}

rename() {
  cd "$chromium_dir/src"

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
      sed -i "s/\\b${replaced_string}\\b/${replacement_string}/g" "$filename"
    done
    find . -type f -name '*.xtb' | while read -r filename; do
      sed -i "s/\\b${replaced_string}\\b/${replacement_string}/g" "$filename"
    done
  done

  git add .
  git commit -m "Browser: Replace Chrome with Browser"
}

domain_substitution() {
  cd "${root_dir}/domain_substitution"
  python3 domain_substitution.py apply -r domain_regex.list -f domain_substitution.list "$chromium_dir/src"
  cd "$chromium_dir/src"
  git add .
  git commit -m "Browser: Automated domain substitution"
}

sync() {
  echo ">> [$(date)] Syncing chromium ${chromium_version}"
  cd "$chromium_dir"
  gclient_config
  if [ -d "$chromium_dir/src" ]; then
    cd "$chromium_dir/src"
    git fetch origin "refs/tags/$chromium_version"
    if [ $clean -eq 1 ]; then
      git checkout main
      git reset --hard FETCH_HEAD
    else
      git reset --hard "$chromium_commit_hash"
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
  target_os_list='[]'
  if [ "$target_os" = "win" ]; then
    target_os_list='["win"]'
  fi

  cat <<EOF2 >"$chromium_dir/.gclient"
solutions = [{
    "url": "$chromium_url@$chromium_commit_hash",
    "managed": False,
    "name": "src",
    "deps_file": 'DEPS',
    "custom_deps": {},
    "custom_vars": {
        "checkout_telemetry_dependencies": False,
        "checkout_pgo_profiles": True,
    }
}]

target_os = $target_os_list
EOF2
}

init_repo() {
  echo ">> [$(date)] Init chromium ${chromium_version}"
  cd "$chromium_dir"
  rm -rf .gclient*
  if [ $history -eq 1 ]; then
    fetch chromium
  else
    fetch --no-history chromium
  fi
}

while getopts ":a:t:cushp" opt; do
  case $opt in
  a) arch="$OPTARG" ;;
  t) target_os=$(normalize_target_os "$OPTARG") ;;
  c) clean=1 ;;
  u) usage ;;
  s) gsync=1 ;;
  h) history=0 ;;
  p) patchonly=1 ;;
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

if [ ! -d "$chromium_dir/depot_tools" ]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$chromium_dir/depot_tools"
else
  cd "$chromium_dir/depot_tools"
  git fetch https://chromium.googlesource.com/chromium/tools/depot_tools.git main
  git reset --hard FETCH_HEAD
  cd "$chromium_dir"
fi
export PATH="$chromium_dir/depot_tools:$PATH"

source "${root_dir}/init-ccache.sh"

chromium_commit_hash=$(git ls-remote --refs "$chromium_url" "refs/tags/$chromium_version" | awk '{print $1}')

if [ $clean -eq 1 ]; then
  echo ">> [$(date)] Cleaning chromium source code"
  if [ -d "$chromium_dir/src" ]; then
    cd "$chromium_dir/src"
    git reset --hard && git clean -xfdf
  fi
fi

if [ ! -d "$chromium_dir/src" ]; then
  init_repo
  sync
fi

if [ $gsync -eq 1 ]; then
  sync
elif [ $patchonly -eq 1 ]; then
  cd "$chromium_dir/src"
  git fetch origin "refs/tags/$chromium_version"
  git checkout main
  git reset --hard FETCH_HEAD
  patch
fi

cd "$chromium_dir/src"
build_desktop

ccache -s
