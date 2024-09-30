#!/bin/bash

branch="v129.0.6668.71-385912cca32ce2d15a3e295f79d5c4dc3a6f7785"
if [ -d cromite ]; then
    cd cromite
    git fetch origin $branch
    git reset --hard FETCH_HEAD
    cd ..
else
    git clone https://gitlab.e.foundation/e/os/cromite.git -b $branch cromite --depth=1
fi

cromite_patches_list=$(cat "cromite_patches_list.txt")
for file in $cromite_patches_list; do
    cp cromite/build/patches/$file "cromite_patches/$file"
done

echo "Copy done"

