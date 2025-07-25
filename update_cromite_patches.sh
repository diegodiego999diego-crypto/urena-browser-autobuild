#!/usr/bin/env bash

root_dir=$(dirname "$(readlink -f "$0")")


branch=$(grep 'cromite_branch' versions.txt | awk -F'"' '{print $2}')

cd $root_dir/build
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
