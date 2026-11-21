import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('demo_reference', ROOT / 'scripts/generate_demo_reference.py')
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class DemoReferenceCompatibilityTests(unittest.TestCase):
    def prepare(self, root):
        (root / 'static').mkdir()
        (root / 'demo').mkdir()
        shutil.copyfile(ROOT / 'static/demo-face.png', root / 'static/demo-face.png')
        reference = json.loads((ROOT / 'demo/face-reference.json').read_text())
        models = {'app-ios/Frameworks/HiFace.xcframework/ios-arm64/HiFace.framework/HiFaceModels/erutaef.bphfm': 'a' * 64}
        reference['modelArtifacts'] = models
        (root / 'demo/face-reference.json').write_text(json.dumps(reference))
        return {'version': 'future-version', 'artifacts': [
            {'destination': name, 'sha256': digest} for name, digest in models.items()]}

    def test_same_models_keep_the_original_extraction_provenance(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            sdk = self.prepare(root)
            (root / 'sdk-artifacts.json').write_text(json.dumps(sdk))
            before = (root / 'demo/face-reference.json').read_bytes()
            generator.generate(root)
            self.assertEqual((root / 'demo/face-reference.json').read_bytes(), before)
            self.assertEqual((root / 'demo/face-reference.js').read_bytes(),
                             (root / 'demo/face-reference.uts').read_bytes())

    def test_changed_missing_or_added_models_require_real_extraction(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            original = self.prepare(root)
            changed = copy.deepcopy(original)
            changed['artifacts'][0]['sha256'] = 'b' * 64
            missing = copy.deepcopy(original)
            missing['artifacts'] = []
            added = copy.deepcopy(original)
            added['artifacts'].append({'destination': added['artifacts'][0]['destination'] + '.new', 'sha256': 'c' * 64})
            for sdk in (changed, missing, added):
                with self.subTest(sdk=sdk):
                    (root / 'sdk-artifacts.json').write_text(json.dumps(sdk))
                    with self.assertRaisesRegex(ValueError, 'models changed'):
                        generator.generate(root)
                    self.assertFalse((root / 'demo/face-reference.js').exists())
