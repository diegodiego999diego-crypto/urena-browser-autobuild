#!/bin/bash

set -e

GITLAB_API="https://gitlab.e.foundation/api/v4"
PROJECT_PATH=$(echo -n "e/os/browser" | jq -sRr @uri)

latest_tag=$(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/repository/tags" \
    | jq -r '.[0].name')
echo "Fetching pipeline for tag $latest_tag..."

pipeline_id=$(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/pipelines?ref=${latest_tag}" \
    | jq -r '.[0].id')
echo "Downloading ruleset_converter from build-cromite-x64, Pipeline ID: $pipeline_id"

job_id=$(curl -s "${GITLAB_API}/projects/${PROJECT_PATH}/pipelines/${pipeline_id}/jobs" \
    | jq -r '.[] | select(.name=="build-cromite-x64") | .id')

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
