#!/bin/bash

root_dir=$(dirname "$(readlink -f "$0")")

chromium_url="https://github.com/chromium/chromium.git"
chromium_version="130.0.6723.67"
patch_list_file="${root_dir}/build/cromite_patches_list.txt"
output_patch_file="${root_dir}/build/e_patches_list.txt"
output_patch_dir="${root_dir}/build/e_patches"

if [ ! -f "$patch_list_file" ]; then
    echo "Error: $patch_list_file does not exist."
    exit 1
fi

if [ -f "$output_patch_file" ]; then
    rm "$output_patch_file"
fi

if [ -d "$output_patch_dir" ]; then
    rm -rf "$output_patch_dir"
fi

last_patch=$(tail -n 1 "$patch_list_file")
subject=${last_patch%.patch}
formatted_subject=${subject//-/" "}

cd ${root_dir}/src || exit 1

chromium_commit_hash=$(git log --pretty=format:"%H %s" | grep -F "$formatted_subject" | head -n 1 | awk '{print $1}')

if [ -z "$chromium_commit_hash" ]; then
    echo "Error: Could not retrieve commit hash for the last patch subject: $formatted_subject"
    exit 1
fi

> "$output_patch_file"
mkdir -p ${root_dir}/build/e_patches

# Patches to ignore
ignore_patches=("Browser-Replace-Chrome-with-Browser.patch" "Browser-Automated-domain-substitution.patch")

for commit in $(git rev-list --reverse "$chromium_commit_hash"..HEAD); do
    subject=$(git log -n 1 --pretty=format:%s "$commit" | tr -d '[:punct:]')
    formatted_subject=${subject// /-}
    patch_filename="${formatted_subject}.patch"

    # Check if the patch filename is in the ignore list
    if [[ " ${ignore_patches[@]} " =~ " ${patch_filename} " ]]; then
        echo "Ignoring patch: $patch_filename"
        continue
    fi

    echo "Creating patch: $patch_filename"
    git format-patch -1 --stdout "$commit" --subject-prefix="" > "$patch_filename"
    echo "$patch_filename" >> "$output_patch_file"
    mv "$patch_filename" "${root_dir}/build/e_patches/"
done
