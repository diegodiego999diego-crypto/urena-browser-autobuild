#!/bin/bash

if [ -d cromite ]; then
    cd cromite
    git fetch origin v127.0.6533.94-5fe9b924075b8c565742b4844362e71aaa9ec0d8
    git reset --hard FETCH_HEAD
    cd ..
else
    git clone https://gitlab.e.foundation/e/os/cromite.git -b v127.0.6533.94-5fe9b924075b8c565742b4844362e71aaa9ec0d8 cromite --depth=1
fi

cromite_patches_list=$(cat "cromite_patches_list.txt")
for file in $cromite_patches_list; do
    cp cromite/build/patches/$file "cromite_patches/$file"
done

echo "Copy done"

