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
    import json, sys
    argv = sys.argv[1:]
    if {mode!r} == "fail":
        sys.exit(3)
    out = argv[argv.index("-o") + 1].split("=", 1)[1]
    with open(out, "w") as fh:
        json.dump({{"ok": True}}, fh)
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

    def _run(self, tool, output, *extra):
        argv = [
            "--format", "spdx_json",
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
        self.assertEqual(json.loads(out.read_text()), {"ok": True})

    def test_syft_failure_fails(self):
        out = self.tmp / "out.json"
        self.assertEqual(self._run(self._fake_syft("fail"), out), 1)
        self.assertFalse(out.exists())

    def test_syft_failure_placeholder_opt_in(self):
        out = self.tmp / "out.json"
        self.assertEqual(self._run(self._fake_syft("fail"), out, "--allow-placeholder"), 0)
        self.assertEqual(json.loads(out.read_text())["tool"], "rules_sbom syft wrapper placeholder")


if __name__ == "__main__":
    unittest.main()
