import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('patch_tool',ROOT/'scripts/apply-patches.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PatchToolTest(unittest.TestCase):
 def test_isolated_apply_idempotent_and_invalid_target(self):
  with tempfile.TemporaryDirectory() as temp:
   base=Path(temp);vendor=base/'vendor';patches=base/'patches';vendor.mkdir();patches.mkdir()
   (vendor/'sample.txt').write_text('old\n')
   (patches/'001.patch').write_text('--- a/sample.txt\n+++ b/sample.txt\n@@ -1 +1 @@\n-old\n+new\n')
   module.apply_all(vendor,patches)
   self.assertEqual((vendor/'sample.txt').read_text(),'new\n')
   module.apply_all(vendor,patches)
   self.assertEqual((vendor/'sample.txt').read_text(),'new\n')
   (vendor/'sample.txt').write_text('incompatible\n')
   with self.assertRaisesRegex(RuntimeError,'neither applicable nor already applied'):
    module.apply_all(vendor,patches)
if __name__=='__main__':unittest.main()
