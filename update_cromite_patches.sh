#!/usr/bin/env bash

set -euo pipefail

root_dir=$(dirname "$(readlink -f "$0")")
branch=$(grep 'cromite_branch' versions.txt | awk -F'"' '{print $2}')
cromite_dir="${root_dir}/build/cromite"

if [ ! -d "${cromite_dir}/.git" ]; then
  echo ">> Cromite submodule not initialized, fetching it now"
  git -C "${root_dir}" submodule update --init --recursive build/cromite
fi

cd "${cromite_dir}"

if [ -n "$(git status --porcelain)" ]; then
  echo "!! Cromite submodule has local changes. Please commit or stash them before updating."
  exit 1
fi

echo ">> Fetching cromite branch/tag ${branch}"
git fetch --tags origin
git fetch origin "${branch}"

git checkout --detach FETCH_HEAD
git reset --hard FETCH_HEAD

echo ">> Cromite submodule updated to $(git rev-parse --short HEAD) (${branch})"
