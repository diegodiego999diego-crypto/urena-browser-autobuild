#!/usr/bin/env bash

root_dir=$(dirname "$(readlink -f "$0")")

branch=$(grep 'ungoogled_chromium_branch' versions.txt | awk -F'"' '{print $2}')

cd $root_dir/domain_substitution

if [ -d ungoogled-chromium ]; then
  cd ungoogled-chromium
  git fetch origin $branch
  git reset --hard FETCH_HEAD
  cd ..
else
  git clone https://github.com/ungoogled-software/ungoogled-chromium -b $branch ungoogled-chromium --depth=1
fi

grep -vFf domain_blacklist.list ungoogled-chromium/domain_substitution.list >domain_substitution.list
cp -r ungoogled-chromium/domain_regex.list domain_regex.list
cd ungoogled-chromium/utils
cp _common.py domain_substitution.py _extraction.py prune_binaries.py ../../

echo "Copy done"
