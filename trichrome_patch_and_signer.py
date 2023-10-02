#!/usr/bin/env python3

import os
import subprocess
import sys
import zipfile

if len(sys.argv) < 3:
    print("Usage: python " + sys.argv[0] + ".py <sign_key.jks/x509.pem> <input_apks>")
    sys.exit(1)

sign_key = sys.argv[1]
input_apks = sys.argv[2:]

def ExtractFingerprint(cert):
    cmd = ['openssl', 'x509', '-sha256', '-fingerprint', '-noout', '-in', cert]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE)
    return proc.stdout.decode('utf-8').split('=')[1].replace(':', '')

def is_valid_key_file(filename):
    return filename.lower().endswith(".x509.pem") or filename.lower().endswith(".jks")

def sign_apk_x509pem(apk, sign_key):
    release_pk8 = sign_key.replace(".x509.pem", ".pk8")
    signing_command = f"apksigner sign --key {release_pk8} --cert {sign_key} {apk}"

    try:
        subprocess.run(signing_command, shell=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error signing APK: {e}")
        return False

def sign_apk_jks(apk, sign_key):
    signing_command = f"apksigner sign --ks {sign_key} {apk}"

    try:
        subprocess.run(signing_command, shell=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error signing APK: {e}")
        return False

def sign_apk(apk, sign_key):
    if sign_key.lower().endswith(".x509.pem"):
        return sign_apk_x509pem(apk, sign_key)
    elif sign_key.lower().endswith(".jks"):
        return sign_apk_jks(apk, sign_key)
    else:
        print(f"Unsupported sign_key file extension: {sign_key_extension}")
        return False

def patch_apk(infilename, sign_key):
    # Default for chromium apks
    orig_certdigest = "32a2fc74d731105859e5a85df16d95f102d85b22099b8064c5d8915c61dad1e0"
    print(f'Original Certificate Digest: {orig_certdigest}')

    # Check if the sign_key has a valid extension
    if not is_valid_key_file(sign_key):
        print(f"Invalid sign_key file extension. Supported extensions are: .jks, .x509.pem")
        return

    new_certdigest = ExtractFingerprint(sign_key).lower().rstrip()

    # Check if the original and new certificate digests are the same
    if orig_certdigest == new_certdigest:
        print("Original and new certificate digests are the same. APK not patched.")
        return

    found_orig_certdigest = False
    found_new_certdigest = False

    with zipfile.ZipFile(infilename, 'r') as zin:
        # Initialize the output ZIP file
        outfilename = infilename + ".patched"
        with zipfile.ZipFile(outfilename, 'w') as zout:
            for info in zin.infolist():
                data = zin.read(info.filename)
                if info.filename == 'AndroidManifest.xml':
                    if new_certdigest.encode('utf-16-le') in data:
                        found_new_certdigest = True
                    # Check if the original certdigest is found
                    if orig_certdigest.encode('utf-16-le') in data:
                        found_orig_certdigest = True
                        # Replace it
                        data = data.replace(orig_certdigest.encode('utf-16-le'), new_certdigest.encode('utf-16-le'))
                        zout.writestr(info, data)

    if found_new_certdigest:
        print(f'New Certificate Digest: {new_certdigest}. APK is already patched.')
        if os.path.exists(outfilename):
            os.remove(outfilename)
        return

    if found_orig_certdigest:
        # Print the new_certdigest before applying the patch
        print(f'New Certificate Digest: {new_certdigest}. APK patched.')
    else:
        print("Original certificate digest not found in 'AndroidManifest.xml'. APK not patched.")
        return

    # Remove the original file if it exists
    if os.path.exists(infilename):
        os.remove(infilename)

    # Rename the output file to the original file name if it exists
    if os.path.exists(outfilename):
        os.rename(outfilename, infilename)

    # Sign the patched APK
    if sign_apk(infilename, sign_key):
        print(f'APK patched and signed')
    else:
        print("Error signing the patched APK. APK not signed.")

def check_tool_availability(tool_name):
    try:
        result = subprocess.run(["which", tool_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, text=True)
        if result.returncode == 0:
            return True
    except subprocess.CalledProcessError as e:
        print(f"Error checking for {tool_name} availability: {e}")
    print(f"Install using sudo apt install {tool_name}.")
    return False

# Check for apksigner availability
if not check_tool_availability("apksigner"):
    sys.exit(1)

# Check for openssl availability
if not check_tool_availability("openssl"):
    sys.exit(1)

for apk in input_apks:
    if not apk.lower().endswith(".apk"):
        print(f"Error: Input APK '{apk}' must have a .apk extension.")
    else:
        patch_apk(apk, sign_key)
