"""Offline regression checks: python3 scripts/test-update-vendor.py."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class UpdateVendorTests(unittest.TestCase):
    def test_update_and_rejected_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "scripts"
            scripts.mkdir()
            script = scripts / "update-vendor.zsh"
            shutil.copyfile(Path(__file__).with_name(script.name), script)
            manifest = root / "vendor-manifest.tsv"
            fixture = root / "formula.json"
            curl = root / "curl"
            curl.write_text('#!/bin/zsh\ncp "$FIXTURE" "${@[-1]}"\n')
            curl.chmod(0o755)
            environment = dict(os.environ, PATH=f"{root}:/usr/bin:/bin", FIXTURE=str(fixture))
            digest = "a" * 64
            bottle = {"sha256": digest,
                      "url": f"https://ghcr.io/v2/homebrew/core/btop/blobs/sha256:{digest}"}
            metadata = {"versions": {"stable": "1.5.0"},
                        "bottle": {"stable": {"files": {"arm64_golden_gate": bottle}}}}

            def run():
                fixture.write_text(json.dumps(metadata))
                return subprocess.run(["/bin/zsh", str(script)], env=environment,
                                      capture_output=True, text=True)

            manifest.write_text("previous manifest\n")
            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f"btop\t1.5.0\t{digest}\t{bottle['url']}\n", manifest.read_text())
            expected = manifest.read_bytes()
            self.assertIn("already up to date", run().stdout)
            for field, value in (("sha256", "invalid"), ("url", "https://example.com/archive")):
                original = bottle[field]
                bottle[field] = value
                self.assertNotEqual(run().returncode, 0)
                self.assertEqual(manifest.read_bytes(), expected)
                bottle[field] = original
            metadata["bottle"]["stable"]["files"] = {}
            self.assertNotEqual(run().returncode, 0)
            self.assertEqual(manifest.read_bytes(), expected)


if __name__ == "__main__":
    unittest.main()
