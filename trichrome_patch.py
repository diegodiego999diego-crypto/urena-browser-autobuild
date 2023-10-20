#!/usr/bin/env python3

import os
import sys
import zipfile

if len(sys.argv) < 3:
    print("Usage: python " + sys.argv[0] + ".py certdigest <input_apks>")
    sys.exit(1)

certdigest = sys.argv[1]
input_apks = sys.argv[2:]

def patch_apk(infilename, new_certdigest):
    # Default for chromium apks
    orig_certdigest = "32a2fc74d731105859e5a85df16d95f102d85b22099b8064c5d8915c61dad1e0"

    # Check if the original and new certificate digests are the same
    if orig_certdigest == new_certdigest:
        return

    delete_apk = False

    with zipfile.ZipFile(infilename, 'r') as zin:
        # Initialize the output ZIP file
        outfilename = infilename + ".patched"
        with zipfile.ZipFile(outfilename, 'w') as zout:
            for info in zin.infolist():
                data = zin.read(info.filename)
                if info.filename == 'AndroidManifest.xml':
                    if new_certdigest.encode('utf-16-le') in data:
                        delete_apk = True
                    # Check if the original certdigest is found
                    if orig_certdigest.encode('utf-16-le') in data:
                        data = data.replace(orig_certdigest.encode('utf-16-le'), new_certdigest.encode('utf-16-le'))
                    else:
                        delete_apk = True
                zout.writestr(info, data)

    if delete_apk and os.path.exists(outfilename):
            os.remove(outfilename)

for apk in input_apks:
    patch_apk(apk, certdigest)
