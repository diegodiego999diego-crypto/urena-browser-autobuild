#!/bin/bash

root_dir=$(dirname "$(readlink -f "$0")")

input_apk=$1
cert=$2
ks_pass=$3
ks_alias=$4

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <input_apk_file> <ks_file> <ks_pass> <ks_alias>"
    exit 1
fi

if [[ "$cert" != *.jks ]]; then
    echo ">> [$(date)] Error: Certificate file must have the extension .jks."
    exit 1
else
    echo ">> [$(date)] Patching apk."
    certdigest=$(openssl x509 -sha256 -fingerprint -noout -in $cert -passin pass:$ks_pass)
    fingerprint=$(echo $certdigest | awk -F'=' '{print $2}' | sed 's/://g' | tr '[:upper:]' '[:lower:]')
    python3 ${root_dir}/trichrome_patch.py $fingerprint $input_apk
fi

output_apk="${input_apk%.apk}_signed.apk"

if [ -f "$input_apk.patched" ]; then
    echo ">> [$(date)] Zipaligning apk."
    zipalign -p -f 4 "$input_apk.patched" $output_apk
    rm "$input_apk.patched"
else
    cp -r $input_apk $output_apk
fi

if [ -f "$output_apk" ]; then
    echo ">> [$(date)] Signing apk."
    apksigner sign --ks $cert --ks-pass pass:$ks_pass --ks-key-alias $ks_alias $output_apk
fi
