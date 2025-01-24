#!/bin/bash

root_dir=$(dirname "$(readlink -f "$0")")

cd $root_dir/build

branch="v132.0.6834.83-36e27b9c60c551348fe4e65a537d16c76d9b48e8"
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

