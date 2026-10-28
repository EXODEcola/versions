"""Unit tests for rules that must be ported into the Electron/Windows updater."""
import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from channel_transition_guard import assess_transition, version_key


class ChannelTransitionTests(unittest.TestCase):
    def setUp(self):
        self.base = dict(installed_version="1.6.13", installed_channel="stable",
                         target_version="1.6.14-beta.1", target_channel="beta",
                         beta_opt_in=True, trusted_asset=True, signed_asset=False,
                         backup_ready=True, unsigned_beta_confirmed=True)

    def decide(self, **patch):
        return assess_transition(**(self.base | patch))

    def test_semver(self):
        self.assertLess(version_key("1.6.14-beta.1"), version_key("1.6.14-beta.2"))
        self.assertLess(version_key("1.6.14-beta.2"), version_key("1.6.14"))
        self.assertGreater(version_key("1.6.14"), version_key("1.6.13"))

    def test_beta_opt_in(self):
        self.assertEqual(self.decide(beta_opt_in=False).reason, "beta-opt-in-required")

    def test_beta_unsigned_confirmation(self):
        self.assertEqual(self.decide(unsigned_beta_confirmed=False).reason,
                         "unsigned-beta-confirmation-required")

    def test_beta_usable_with_explicit_consent(self):
        d = self.decide()
        self.assertTrue(d.allowed)
        self.assertEqual(d.action, "upgrade")

    def test_never_allow_untested_asset(self):
        self.assertEqual(self.decide(trusted_asset=False).reason, "unverified-release")

    def test_stable_signed_required(self):
        self.assertEqual(self.decide(target_version="1.6.14", target_channel="stable",
                                     signed_asset=False).reason, "unsigned-stable")

    def test_stable_upgrade(self):
        self.assertTrue(self.decide(target_version="1.6.14", target_channel="stable",
                                    signed_asset=True).allowed)

    def test_downgrade_not_channel_toggle(self):
        self.assertEqual(self.decide(installed_version="1.6.14-beta.1",
                                     target_version="1.6.13", target_channel="stable",
                                     signed_asset=True).reason, "downgrade-needs-explicit-rollback")

    def test_explicit_rollback_requires_snapshot(self):
        self.assertEqual(self.decide(installed_version="1.6.14-beta.1",
                                     target_version="1.6.13", target_channel="stable",
                                     signed_asset=True, explicit_rollback=True).reason,
                         "rollback-snapshot-incompatible")

    def test_explicit_rollback_validated(self):
        d = self.decide(installed_version="1.6.14-beta.1", target_version="1.6.13",
                        target_channel="stable", signed_asset=True, explicit_rollback=True,
                        rollback_snapshot_compatible=True)
        self.assertTrue(d.allowed)
        self.assertEqual(d.action, "restore")

    def test_backup_required(self):
        self.assertEqual(self.decide(backup_ready=False).reason, "backup-required")

    def test_same_version_beta_stable_needs_explicit(self):
        self.assertEqual(self.decide(installed_version="1.6.13", installed_channel="beta",
                                     target_version="1.6.13", target_channel="stable",
                                     signed_asset=True).reason,
                         "same-version-cross-channel-needs-explicit-action")

    def test_no_beta_manifest_in_stable(self):
        self.assertEqual(self.decide(target_channel="stable",signed_asset=True).reason,
                         "prerelease-in-stable")

    def test_invalid_version_and_channel(self):
        self.assertFalse(self.decide(target_version="dev-14").allowed)
        self.assertFalse(self.decide(target_channel="nightly").allowed)

    def test_equal_is_no_action(self):
        d = self.decide(installed_version="1.6.14-beta.1",installed_channel="beta")
        self.assertEqual(d.action,"up-to-date")

if __name__ == "__main__":
    unittest.main()