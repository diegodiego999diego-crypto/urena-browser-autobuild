#!/bin/bash

root_dir=$(dirname "$(readlink -f "$0")")

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

last_patch=$(tail -n 1 "$patch_list_file")
subject=${last_patch%.patch}
formatted_subject=${subject//-/" "}

cd "${root_dir}/src" || exit 1

chromium_commit_hash=$(git log --pretty=format:"%H %s" | grep -F "$formatted_subject" | head -n 1 | awk '{print $1}')

if [ -z "$chromium_commit_hash" ]; then
    echo "Error: Could not retrieve commit hash for the last patch subject: $formatted_subject"
    exit 1
fi

> "$output_patch_file"
mkdir -p "$output_patch_dir"

# Patches to ignore
ignore_patches=("Browser-Replace-Chrome-with-Browser.patch" "Browser-Automated-domain-substitution.patch")

for commit in $(git rev-list --reverse "$chromium_commit_hash"..HEAD); do
    subject=$(git log -n 1 --pretty=format:%s "$commit" | tr -d '[:punct:]')
    formatted_subject=${subject// /-}
    patch_filename="${formatted_subject}.patch"
    patch_path="${output_patch_dir}/${patch_filename}"

    # Check if the patch filename is in the ignore list
    if [[ " ${ignore_patches[@]} " =~ " ${patch_filename} " ]]; then
        echo "Ignoring patch: $patch_filename"
        continue
    fi

    # Generate the patch to a temporary file
    temp_patch_file=$(mktemp)
    git format-patch -1 --stdout "$commit" --subject-prefix="" > "$temp_patch_file"

    # Check if the patch differs from any existing one, ignoring the first line and the last non-empty line
    if [ -f "$patch_path" ]; then
        # Remove trailing empty lines and skip the first and last non-empty line
        temp_content=$(sed '/./!d' "$temp_patch_file" | tail -n +2 | head -n -1)
        existing_content=$(sed '/./!d' "$patch_path" | tail -n +2 | head -n -1)

        # Compare processed content
        if diff -q <(echo "$temp_content") <(echo "$existing_content") > /dev/null; then
            echo "Patch already up-to-date: $patch_filename"
            rm "$temp_patch_file"
            echo "$patch_filename" >> "$output_patch_file"
            continue
        fi
    fi

    # Move the patch to the output directory if it’s new or updated
    echo "Updating patch: $patch_filename"
    mv "$temp_patch_file" "$patch_path"
    echo "$patch_filename" >> "$output_patch_file"
done
