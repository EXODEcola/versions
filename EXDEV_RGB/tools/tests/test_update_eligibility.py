"""Updater policy tests; no Windows privileges, network calls or filesystem writes."""
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from update_eligibility import evaluate


def feed(version="1.6.11"):
    return {"product": "EXDEV RGB", "channel": "stable", "latest": version}


def manifest(version="1.6.11"):
    asset = f"EXDEV_RGB_v{version}_OFFICIAL.zip"
    return {
        "product": "EXDEV RGB", "channel": "stable", "status": "current", "version": version,
        "download": {
            "available": True, "provider": "github-release", "repository": "EXODEcola/versions",
            "tag": f"v{version}", "asset": asset,
            "url": f"https://github.com/EXODEcola/versions/releases/download/v{version}/{asset}",
            "sha256": "A" * 64, "size": 6000000,
        },
    }


class UpdateEligibilityTests(unittest.TestCase):
    def test_registry_1610_binary_168_promotes_from_real_binary(self):
        x = evaluate("1.6.8", feed(), manifest(), "1.6.10")
        self.assertTrue(x.should_update)
        self.assertTrue(x.registry_version_mismatch)
        self.assertEqual(x.latest_version, "1.6.11")

    def test_repo_160_never_downgrades_168(self):
        x = evaluate("1.6.8", feed("1.6.0"), None, "1.6.10")
        self.assertFalse(x.should_update)
        self.assertEqual(x.reason, "up_to_date_or_remote_older_no_downgrade")

    def test_prepared_not_installed(self):
        m = manifest(); m["status"] = "prepared"
        self.assertFalse(evaluate("1.6.8", feed(), m).should_update)

    def test_no_real_asset(self):
        m = manifest(); m["download"]["available"] = False
        self.assertEqual(evaluate("1.6.8", feed(), m).reason, "asset_not_available")

    def test_never_accept_untrusted_host(self):
        m = manifest(); m["download"]["url"] = "https://bad.example/official.zip"
        self.assertEqual(evaluate("1.6.8", feed(), m).reason, "untrusted_release_source")

    def test_reject_unsigned_metadata_no_checksum(self):
        m = manifest(); m["download"]["sha256"] = ""
        self.assertEqual(evaluate("1.6.8", feed(), m).reason, "invalid_sha256_metadata")

    def test_prevent_downgrade_and_same_version(self):
        self.assertFalse(evaluate("1.6.11", feed(), manifest()).should_update)
        self.assertFalse(evaluate("1.6.12", feed(), manifest()).should_update)

    def test_untrusted_channel(self):
        f = feed(); f["channel"] = "beta"
        self.assertFalse(evaluate("1.6.8", f, manifest()).should_update)

    def test_missing_installed_version_requires_repair(self):
        self.assertEqual(evaluate("bad", feed(), manifest()).reason, "invalid_installed_binary_version_manual_repair")

    def test_unsafe_zip_filename(self):
        m = manifest(); m["download"]["asset"] = "../wrong.zip"
        self.assertEqual(evaluate("1.6.8", feed(), m).reason, "unsafe_archive_name")

    def test_manifest_mismatch(self):
        m = manifest(); m["version"] = "1.6.10"
        self.assertFalse(evaluate("1.6.8", feed(), m).should_update)


if __name__ == "__main__":
    unittest.main()