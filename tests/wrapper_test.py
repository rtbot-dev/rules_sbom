import io
import json
import os
import stat
import sys
import tempfile
import textwrap
import unittest
from contextlib import redirect_stderr
from pathlib import Path

import wrapper

FAKE_SYFT = textwrap.dedent("""\
    #!{python}
    import datetime, json, sys, uuid
    argv = sys.argv[1:]
    if {mode!r} == "fail":
        sys.exit(3)
    fmt, out = argv[argv.index("-o") + 1].split("=", 1)
    stamp = datetime.datetime.now().isoformat()
    if fmt == "spdx-json":
        doc = {{
            "name": "x",
            "documentNamespace": "https://anchore.com/syft/dir/x-" + str(uuid.uuid4()),
            "creationInfo": {{"created": stamp}},
        }}
    else:
        doc = {{"serialNumber": "urn:uuid:" + str(uuid.uuid4()), "metadata": {{"timestamp": stamp}}}}
    with open(out, "w") as fh:
        json.dump(doc, fh)
    with open(out + ".argv", "w") as fh:
        json.dump(argv, fh)
""")


class WrapperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(dir=os.environ.get("TEST_TMPDIR")))
        src = self.tmp / "requirements.txt"
        src.write_text("requests==2.32.3\n", encoding="utf-8")
        self.manifest = self.tmp / "inputs.list"
        self.manifest.write_text(f"{src}\tpkg/requirements.txt\n", encoding="utf-8")

    def _fake_syft(self, mode="ok"):
        tool = self.tmp / f"syft_{mode}"
        tool.write_text(FAKE_SYFT.format(python=sys.executable, mode=mode), encoding="utf-8")
        tool.chmod(tool.stat().st_mode | stat.S_IXUSR)
        return tool

    def _run(self, tool, output, *extra, fmt="spdx_json"):
        argv = [
            "--format", fmt,
            "--output", str(output),
            "--target", "//pkg:lib",
            "--inputs-manifest", str(self.manifest),
            "--tool", str(tool),
            *extra,
        ]
        with redirect_stderr(io.StringIO()):
            return wrapper.main(argv)

    def test_syft_success(self):
        out = self.tmp / "out.json"
        self.assertEqual(self._run(self._fake_syft(), out), 0)
        self.assertEqual(json.loads(out.read_text())["name"], "x")

    def test_syft_failure_fails(self):
        out = self.tmp / "out.json"
        self.assertEqual(self._run(self._fake_syft("fail"), out), 1)
        self.assertFalse(out.exists())

    def test_syft_failure_placeholder_opt_in(self):
        out = self.tmp / "out.json"
        self.assertEqual(self._run(self._fake_syft("fail"), out, "--allow-placeholder"), 0)
        self.assertEqual(json.loads(out.read_text())["tool"], "rules_sbom syft wrapper placeholder")

    def test_source_name_and_version_passed(self):
        out = self.tmp / "out.json"
        self.assertEqual(self._run(self._fake_syft(), out, "--source-name", "//pkg:lib", "--source-version", "1.2.3"), 0)
        argv = json.loads(Path(f"{out}.argv").read_text())
        self.assertEqual(argv[argv.index("--source-name") + 1], "//pkg:lib")
        self.assertEqual(argv[argv.index("--source-version") + 1], "1.2.3")

    def test_spdx_output_is_deterministic(self):
        tool = self._fake_syft()
        first, second = self.tmp / "a.json", self.tmp / "b.json"
        self.assertEqual(self._run(tool, first), 0)
        self.assertEqual(self._run(tool, second), 0)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        doc = json.loads(first.read_text())
        self.assertEqual(doc["creationInfo"]["created"], "1970-01-01T00:00:00Z")
        self.assertRegex(doc["documentNamespace"], r"^https://anchore\.com/syft/dir/x-[0-9a-f-]{36}$")

    def test_cyclonedx_output_is_deterministic(self):
        tool = self._fake_syft()
        first, second = self.tmp / "a.json", self.tmp / "b.json"
        self.assertEqual(self._run(tool, first, fmt="cyclonedx_json"), 0)
        self.assertEqual(self._run(tool, second, fmt="cyclonedx_json"), 0)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        self.assertEqual(json.loads(first.read_text())["metadata"]["timestamp"], "1970-01-01T00:00:00Z")


if __name__ == "__main__":
    unittest.main()
