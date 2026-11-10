#!/usr/bin/env python3
"""Copy the shared plugin and app icon assets into the uvue example."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
plugin_id = 'HelloFace-Verify'
destination = root / 'examples' / 'uni-app-x' / 'uni_modules' / plugin_id
# This example directory is generated; remove the former ID to avoid duplicate modules.
legacy = destination.parent / 'HelloFaceVerify'
if legacy.is_dir():
    shutil.rmtree(legacy)
shutil.copytree(root / 'uni_modules' / plugin_id, destination, dirs_exist_ok=True)
shutil.copytree(root / 'app-icons', destination.parent.parent / 'app-icons', dirs_exist_ok=True)
print('Prepared ' + str(destination.parent.parent))
