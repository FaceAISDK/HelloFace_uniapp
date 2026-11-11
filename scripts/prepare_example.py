#!/usr/bin/env python3
"""Copy the shared plugin and app icon assets into the uvue example."""
from pathlib import Path
import shutil
from generate_demo_reference import generate

root = Path(__file__).resolve().parents[1]
generate(root)
plugin_id = 'HelloFace-Verify'
destination = root / 'examples' / 'uni-app-x' / 'uni_modules' / plugin_id
# This example directory is generated; remove the former ID to avoid duplicate modules.
legacy = destination.parent / 'HelloFaceVerify'
if legacy.is_dir():
    shutil.rmtree(legacy)
shutil.copytree(root / 'uni_modules' / plugin_id, destination, dirs_exist_ok=True)
shutil.copytree(root / 'app-icons', destination.parent.parent / 'app-icons', dirs_exist_ok=True)
shutil.copytree(root / 'demo', destination.parent.parent / 'demo', dirs_exist_ok=True)
shutil.copytree(root / 'static', destination.parent.parent / 'static', dirs_exist_ok=True)
print('Prepared ' + str(destination.parent.parent))
