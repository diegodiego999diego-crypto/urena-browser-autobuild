#!/usr/bin/env bash

root_dir=$(dirname "$(readlink -f "$0")")

cd $root_dir/build

branch="v138.0.7204.97-418943de425329115e0783375c12ee5aec36e2b6"
if [ -d cromite ]; then
    cd cromite
    git fetch origin $branch
    git reset --hard FETCH_HEAD
    cd ..
else
    git clone https://gitlab.e.foundation/e/os/cromite.git -b $branch cromite --depth=1
fi

rm -rf cromite_patches/*

cromite_patches_list=$(cat "cromite_patches_list.txt")
for file in $cromite_patches_list; do
    cp cromite/build/patches/$file "cromite_patches/$file"
done

echo "Copy done"
