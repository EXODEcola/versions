import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile

SOURCE = Path(__file__).resolve().parents[1] / "release_guard.py"
spec = importlib.util.spec_from_file_location("release_guard", SOURCE)
release_guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_guard)


class ReleaseGuardTests(unittest.TestCase):
    def test_semver_numeric(self):
        self.assertLess(release_guard.semver("1.6.8"), release_guard.semver("1.6.11"))
        with self.assertRaises(release_guard.ReleaseError):
            release_guard.semver("1.6.11-beta")

    def test_archive_integrity_and_installer(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "EXDEV.zip"
            with ZipFile(p, "w") as z:
                z.writestr("EXDEV RGB/EXDEV_RGB_INSTALLER.exe", "installer-placeholder")
                z.writestr("EXDEV RGB/Lib/README.txt", "native assets")
            m = {"download": {"sha256": hashlib.sha256(p.read_bytes()).hexdigest(), "size": p.stat().st_size}}
            self.assertIn("Verified:", release_guard.verify_archive(p, m))
            m["download"]["size"] -= 1
            with self.assertRaises(release_guard.ReleaseError):
                release_guard.verify_archive(p, m)

    def test_reject_missing_installer(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "incomplete.zip"
            with ZipFile(p, "w") as z:
                z.writestr("EXDEV RGB.exe", "no installer")
            m = {"download": {"sha256": hashlib.sha256(p.read_bytes()).hexdigest(), "size": p.stat().st_size}}
            with self.assertRaises(release_guard.ReleaseError):
                release_guard.verify_archive(p, m)

    def test_reject_unsafe_zip_paths(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "unsafe.zip"
            with ZipFile(p, "w") as z:
                z.writestr("EXDEV_RGB_INSTALLER.exe", "installer")
                z.writestr("../bad.exe", "bad")
            m = {"download": {"sha256": hashlib.sha256(p.read_bytes()).hexdigest(), "size": p.stat().st_size}}
            with self.assertRaises(release_guard.ReleaseError):
                release_guard.verify_archive(p, m)


if __name__ == "__main__":
    unittest.main()