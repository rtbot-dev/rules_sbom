import json
import sys
import unittest
from pathlib import Path

SBOM_PATH = Path(sys.argv.pop(1))


class ImageSbomTest(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads(SBOM_PATH.read_text(encoding="utf-8"))

    def test_scanned_as_image(self):
        names = {p.get("name") for p in self.doc.get("packages", [])}
        self.assertIn("musl", names)
        self.assertIn("busybox", names)

    def test_source_identity(self):
        self.assertEqual(self.doc["name"], "//examples/oci:image")
        self.assertIn("/image/", self.doc["documentNamespace"])

    def test_deterministic_metadata(self):
        self.assertEqual(self.doc["creationInfo"]["created"], "1970-01-01T00:00:00Z")


if __name__ == "__main__":
    unittest.main()
