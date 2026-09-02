#!/usr/bin/env bash

root_dir=$(dirname "$(readlink -f "$0")")

output_patch_dir="${root_dir}/build/cromite_patches"
output_patch_file="${root_dir}/build/cromite_patches_list.txt"
chromium_version=$(grep 'chromium_version' versions.txt | awk -F'"' '{print $2}')

cd "${root_dir}/src" || exit 1

chromium_commit_hash=$(git ls-remote origin refs/tags/$chromium_version | awk '{print $1}')

if [ -z "$chromium_commit_hash" ]; then
  echo "Error: Could not retrieve commit hash for the last patch subject: $formatted_subject"
  exit 1
fi

>"$output_patch_file"

# Patches to ignore
ignore_patches=("Browser-Replace-Chrome-with-Browser.patch" "Browser-Automated-domain-substitution.patch")

for commit in $(git rev-list --reverse "$chromium_commit_hash"..HEAD); do
  subject=$(git log -n 1 --pretty=format:%s "$commit" | tr -d ':,"')
  formatted_subject=$(echo "$subject" | sed 's/[^[:alnum:]_.-]/-/g; s/-\+/-/g')
  patch_filename="${formatted_subject}.patch"
  patch_path="${output_patch_dir}/${patch_filename}"

  # Generate the patch to a temporary file
  temp_patch_file=$(mktemp)
  git format-patch -1 --stdout "$commit" --subject-prefix="" >"$temp_patch_file"

  # Check if the patch differs from any existing one, ignoring the first line and the last non-empty line
  if [ -f "$patch_path" ]; then
    # Remove trailing empty lines and skip the first and last non-empty line
    temp_content=$(sed '/./!d' "$temp_patch_file" | tail -n +2 | head -n -1)
    existing_content=$(sed '/./!d' "$patch_path" | tail -n +2 | head -n -1)

    # Compare processed content
    if diff -q <(echo "$temp_content") <(echo "$existing_content") >/dev/null; then
      echo "Patch already up-to-date: $patch_filename"
      rm "$temp_patch_file"
      echo "$patch_filename" >>"$output_patch_file"
      continue
    fi
  fi

  # Move the patch to the output directory if it’s new or updated
  echo "Updating patch: $patch_filename"
  mv "$temp_patch_file" "$patch_path"
  echo "$patch_filename" >>"$output_patch_file"
done
