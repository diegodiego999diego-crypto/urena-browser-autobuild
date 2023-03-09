#!/bin/bash

set -e

chromium_dir="${chromium_dir:-/srv/chromium}"
root_dir=$(dirname "$(readlink -f "$0")")
if [ ! -d "$chromium_dir" ]; then
    chromium_dir=$root_dir
fi

cd $chromium_dir/src

# Translation directories
dirs="components components/strings chrome/browser/ui/android/strings chrome/browser/ui/android/strings/translations"

for dir in $dirs; do
    grdp_files=$(ls $dir/*.grdp 2> /dev/null | wc -l)
    if [ "$grdp_files" != "0" ]; then
        sed -i 's/Chrome browser/Browser/g' $dir/*.grdp
        sed -i 's/Chrome/Browser/g' $dir/*.grdp
    fi
    xtb_files=$(ls $dir/*.xtb 2> /dev/null | wc -l)
    if [ "$xtb_files" != "0" ]; then
        sed -i 's/Chrome browser/Browser/g' $dir/*.xtb
        sed -i 's/Chrome/Browser/g' $dir/*.xtb
    fi
done

git add .
git commit -m "Browser: Replace Chrome with Browser"
