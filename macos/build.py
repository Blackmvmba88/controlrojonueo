#!/usr/bin/env python3
"""Build a native candidate; does not replace a running installation."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import os

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'build' / 'ControlGame.app'
for tool in ('swiftc', 'sips', 'iconutil', 'codesign'):
    if not shutil.which(tool):
        raise SystemExit(f'Falta {tool}. Instala las herramientas de desarrollo de macOS.')
if APP.exists():
    shutil.rmtree(APP)
macos = APP / 'Contents' / 'MacOS'
resources = APP / 'Contents' / 'Resources'
macos.mkdir(parents=True)
resources.mkdir(parents=True)
subprocess.run(['swiftc', '-O', str(ROOT / 'macos/main.swift'), str(ROOT / 'macos/Dashboard.swift'), str(ROOT / 'macos/CardNavigator.swift'), '-framework', 'AppKit',
                '-framework', 'GameController', '-framework', 'ApplicationServices',
                '-o', str(macos / 'ControlGame')], check=True)
iconset = ROOT / 'build' / 'AppIcon.iconset'
iconset.mkdir(exist_ok=True)
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
        subprocess.run(['sips', '-z', str(size * scale), str(size * scale),
                        str(ROOT / 'assets/ControlGame.png'), '--out', str(iconset / name)],
                       check=True, stdout=subprocess.DEVNULL)
subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(resources / 'AppIcon.icns')], check=True)
(APP / 'Contents/Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.blackmamba.ControlGame',
    'CFBundleName': 'ControlGame', 'CFBundleDisplayName': 'ControlGame',
    'CFBundleExecutable': 'ControlGame', 'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '1.3.0', 'CFBundleVersion': '5',
    'CFBundleIconFile': 'AppIcon', 'LSMinimumSystemVersion': '12.0',
    'NSHighResolutionCapable': True,
    'NSBluetoothAlwaysUsageDescription': 'Conectar el mando Xbox para navegar por el escritorio.',
}))
shutil.copy2(ROOT / 'INSTRUCCIONES-CONTROL.md', resources / 'Instrucciones.md')
# Keep the same signing identity across updates. Never silently fall back to ad hoc.
identity = os.environ.get('CONTROLGAME_SIGN_IDENTITY', 'BlackMamba ControlGame Local Signing')
identities = subprocess.run(['security', 'find-identity', '-v', '-p', 'codesigning'], capture_output=True, text=True, check=True).stdout
if identity == '-' or identity not in identities:
    raise SystemExit('Falta una identidad estable de firma. Ejecuta scripts/setup-signing.py con autorización del usuario.')
subprocess.run(['codesign', '--force', '--sign', identity, str(APP)], check=True)
subprocess.run(['codesign', '--verify', '--strict', str(APP)], check=True)
print(APP)
