#!/usr/bin/env bash

root_dir=$(dirname "$(readlink -f "$0")")

cd $root_dir/build

branch="v133.0.6943.99-f987ea3d750501f851e708a49b2c66e318206e73"
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
