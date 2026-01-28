#!/bin/bash

set -e

GITLAB_API="https://gitlab.e.foundation/api/v4"
PROJECT_PATH=$(echo -n "e/os/browser" | jq -sRr @uri)

for tag in $(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/repository/tags" | jq -r '.[].name'); do
  echo "Checking tag: $tag"

  pipeline_id=$(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/pipelines?ref=${tag}" |
    jq -r '.[0].id')

  job_id=$(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/pipelines/${pipeline_id}/jobs" |
    jq -r '.[] | select(.name=="archive-filter" and .status=="success") | .id')

  if [ "$job_id" != "null" ] && [ -n "$job_id" ]; then
    echo "Found successful archive-filter job for tag $tag (Job ID: $job_id)"
    selected_tag=$tag
    break
  fi
done

if [ -z "$selected_tag" ]; then
  echo "No tag with successful job found"
  exit 1
fi

echo "Downloading ruleset_converter from job $job_id..."
curl -L \
  --output ruleset_converter \
  "${GITLAB_API}/projects/${PROJECT_PATH}/jobs/${job_id}/artifacts/bin/ruleset_converter"

chmod +x ruleset_converter

echo "Downloading filter lists..."
curl -o easylist.txt https://easylist.to/easylist/easylist.txt
curl -o easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt

filter_inputs="easyprivacy.txt,easylist.txt"

echo "Generating filters.dat from $filter_inputs"
./ruleset_converter --input_format=filter-list \
  --output_format=unindexed-ruleset \
  --input_files=$filter_inputs \
  --output_file=filters.dat >/dev/null 2>&1
