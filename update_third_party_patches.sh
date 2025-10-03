#!/usr/bin/env bash

root_dir=$(dirname "$(readlink -f "$0")")

while read dir patch; do
  [ -z "$dir" ] && continue # skip empty lines
  subject=${patch%.patch}
  formatted_subject=${subject//-/" "}
  echo "Updating patch: $formatted_subject"
  cd $root_dir/src/third_party/$dir
  commit_hash=$(git log --pretty=format:"%H %s" | grep -F "$formatted_subject" | head -n 1 | awk '{print $1}')
  git format-patch -1 --stdout "$commit_hash" --subject-prefix="" >$root_dir/build/third_party/$patch
done <"${root_dir}/build/third_party_patches_list.txt"
