#!/usr/bin/env python3

import os
import sys
import subprocess
import zipfile

def main():
    if len(sys.argv) != 5:
        print("Usage: {} <input_apk_file> <ks_file> <ks_pass> <ks_alias>".format(sys.argv[0]))
        sys.exit(1)

    input_apk = sys.argv[1]
    cert = sys.argv[2]
    ks_pass = sys.argv[3]
    ks_alias = sys.argv[4]

    root_dir = os.path.dirname(os.path.realpath(__file__))

    if not cert.endswith(".jks"):
        print(">> [{}] Error: Certificate file must have the extension .jks.".format(get_current_time()))
        sys.exit(1)
    else:
        print(">> [{}] Patching apk.".format(get_current_time()))
        certdigest = get_certificate_fingerprint(cert, ks_pass)
        fingerprint = certdigest.replace(':', '').lower()
        patch_apk(root_dir, fingerprint, input_apk)

    output_apk = "{}_signed.apk".format(os.path.splitext(input_apk)[0])

    if os.path.exists("{}_patched".format(input_apk)):
        print(">> [{}] Zipaligning apk.".format(get_current_time()))
        zipalign_apk("{}_patched".format(input_apk), output_apk)
        os.remove("{}_patched".format(input_apk))
    else:
        subprocess.run(["cp", input_apk, output_apk])

    if os.path.exists(output_apk):
        print(">> [{}] Signing apk.".format(get_current_time()))
        sign_apk(cert, ks_pass, ks_alias, output_apk)

def get_current_time():
    return subprocess.check_output("date", shell=True).decode().strip()

def get_certificate_fingerprint(cert, ks_pass):
    certdigest = subprocess.check_output("openssl x509 -sha256 -fingerprint -noout -in {} -passin pass:{}".format(cert, ks_pass), shell=True).decode().strip()
    return certdigest.split('=')[1].replace(':', '').lower()

def patch_apk(root_dir, new_certdigest, input_apk):
    orig_certdigest = "32a2fc74d731105859e5a85df16d95f102d85b22099b8064c5d8915c61dad1e0"

    if orig_certdigest == new_certdigest:
        return

    delete_apk = False

    with zipfile.ZipFile(input_apk, 'r') as zin:
        outfilename = "{}_patched".format(input_apk)
        with zipfile.ZipFile(outfilename, 'w') as zout:
            for info in zin.infolist():
                data = zin.read(info.filename)
                if info.filename == 'AndroidManifest.xml':
                    if new_certdigest.encode('utf-16-le') in data:
                        delete_apk = True
                    elif orig_certdigest.encode('utf-16-le') in data:
                        data = data.replace(orig_certdigest.encode('utf-16-le'), new_certdigest.encode('utf-16-le'))
                    else:
                        delete_apk = True
                zout.writestr(info, data)

    if delete_apk and os.path.exists(outfilename):
        os.remove(outfilename)

def zipalign_apk(input_apk, output_apk):
    subprocess.run(["zipalign", "-f", "-p", "-z", "4",  input_apk, output_apk])

def sign_apk(cert, ks_pass, ks_alias, output_apk):
    subprocess.run(["apksigner", "sign", "--ks", cert, "--ks-pass", "pass:{}".format(ks_pass), "--ks-key-alias", ks_alias, output_apk])

if __name__ == "__main__":
    main()
