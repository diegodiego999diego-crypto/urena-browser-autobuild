#!/bin/bash

if [ -d ungoogled-chromium ]; then
    cd ungoogled-chromium
    git fetch origin 127.0.6533.88-1
    git reset --hard FETCH_HEAD
    cd ..
else
    git clone https://github.com/ungoogled-software/ungoogled-chromium -b 127.0.6533.88-1 ungoogled-chromium --depth=1
fi

grep -vFf domain_blacklist.list ungoogled-chromium/domain_substitution.list > domain_substitution.list
cp -r ungoogled-chromium/domain_regex.list domain_regex.list

echo "Copy done"

