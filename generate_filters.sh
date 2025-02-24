#!/bin/bash

curl -o easylist.txt https://easylist.to/easylist/easylist.txt
curl -o easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt

filter_inputs="easyprivacy.txt,easylist.txt"

echo "Generating filters.dat from $filter_inputs"
./ruleset_converter --input_format=filter-list \
    --output_format=unindexed-ruleset \
    --input_files=$filter_inputs \
    --output_file=filters.dat >/dev/null 2>&1
