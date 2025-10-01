#!/bin/bash

# Check if shfmt is installed
if ! command -v shfmt &>/dev/null; then
  echo "shfmt is not installed. Please install shfmt (curl -sS https://webi.sh/shfmt | sh) to fix formatting."
  exit 0
fi

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "$0")"/ && pwd)"

# Use git to list all shell scripts (respects .gitignore)
FILES=$(git -C "$SCRIPT_DIR" ls-files --cached --others --exclude-standard '*.sh')

if [[ -z "$FILES" ]]; then
  echo "No shell scripts found to format."
  exit 0
fi

# Format each file
for script_file in $FILES; do
  echo "Formatting $script_file ..."
  shfmt -w -i 2 "$SCRIPT_DIR/$script_file"
  git add "$SCRIPT_DIR/$script_file"
done

echo "Formatting complete!"
