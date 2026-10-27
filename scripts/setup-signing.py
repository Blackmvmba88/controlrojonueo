#!/usr/bin/env python3
"""User-authorized local code-signing setup; private files stay outside source."""
import os
from pathlib import Path
import secrets
import subprocess
import tempfile

name = 'BlackMamba ControlGame Local Signing'
folder = Path.home() / 'Library/Application Support/ControlGame/signing'
folder.mkdir(parents=True, exist_ok=True, mode=0o700)
folder.chmod(0o700)
cert = folder / 'ControlGame-Signing.cer'
key = folder / 'ControlGame-Signing.key'
keychain = Path.home() / 'Library/Keychains/login.keychain-db'

def run(args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    if result.returncode:
        print(result.stderr[:1500])
        raise SystemExit('No se completó la configuración de firma; no se reemplazó la app.')
    if result.stdout:
        print(result.stdout[:1000])
    return result

identities = run(['security', 'find-identity', '-v', '-p', 'codesigning']).stdout
if name in identities:
    print('La identidad ya está lista.')
    raise SystemExit(0)
if not cert.exists():
    with tempfile.TemporaryDirectory() as temp:
        config = Path(temp) / 'certificate.conf'
        config.write_text('''[req]
prompt=no
distinguished_name=dn
x509_extensions=ext
[dn]
CN=BlackMamba ControlGame Local Signing
O=BlackMamba Local
[ext]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
''')
        run(['/usr/bin/openssl', 'req', '-new', '-newkey', 'rsa:2048', '-nodes', '-x509', '-sha256',
             '-days', '3650', '-config', str(config), '-keyout', str(key), '-out', str(cert)])
        key.chmod(0o600)
        cert.chmod(0o600)
with tempfile.TemporaryDirectory() as temp:
    p12 = Path(temp) / 'identity.p12'
    env = dict(os.environ, CONTROLGAME_P12_PASSWORD=secrets.token_urlsafe(32))
    run(['/usr/bin/openssl', 'pkcs12', '-export', '-inkey', str(key), '-in', str(cert),
         '-name', name, '-out', str(p12), '-passout', 'env:CONTROLGAME_P12_PASSWORD'], env=env)
    run(['security', 'import', str(p12), '-k', str(keychain), '-P', env['CONTROLGAME_P12_PASSWORD'],
         '-T', '/usr/bin/codesign'])
print('Configurando confianza de firma para el usuario; macOS puede pedir autorización.')
run(['security', 'add-trusted-cert', '-r', 'trustRoot', '-p', 'codeSign', '-k', str(keychain), str(cert)])
run(['security', 'find-identity', '-v', '-p', 'codesigning'])
print('Firma local configurada. La clave privada no está en el repositorio.')
