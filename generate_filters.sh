#!/bin/bash

set -e

GITLAB_API="https://gitlab.e.foundation/api/v4"
PROJECT_PATH=$(echo -n "e/os/browser" | jq -sRr @uri)

for tag in $(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/repository/tags" | jq -r '.[].name'); do
  echo "Checking tag: $tag"

  pipeline_id=$(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/pipelines?ref=${tag}&status=success" |
    jq -r '.[0].id')

  if [ "$pipeline_id" != "null" ] && [ -n "$pipeline_id" ]; then
    echo "Found successful pipeline for tag $tag (Pipeline ID: $pipeline_id)"
    selected_tag=$tag
    break
  fi
done

if [ -z "$selected_tag" ]; then
  echo "No tag with successful pipeline found"
  exit 1
fi

echo "Looking for archive-filter job in pipeline $pipeline_id..."

job_id=$(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/pipelines/${pipeline_id}/jobs" |
  jq -r '.[] | select(.name=="archive-filter") | .id')

if [ -z "$job_id" ]; then
  echo "No job named archive-filter found in pipeline $pipeline_id"
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
