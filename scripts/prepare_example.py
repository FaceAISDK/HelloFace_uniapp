#!/usr/bin/env python3
"""Copy the single plugin source into the uvue example for HBuilderX."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
destination = root / 'examples' / 'uni-app-x' / 'uni_modules' / 'HelloFaceVerify'
shutil.copytree(root / 'uni_modules' / 'HelloFaceVerify', destination, dirs_exist_ok=True)
print('Prepared ' + str(destination.parent.parent))
