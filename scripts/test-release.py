"""Offline integration checks: python3 scripts/test-release.py."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.project = root / "project"
        self.remote = root / "origin.git"
        self.project.mkdir()
        self.environment = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        self.git("init", "--bare", "-q", "-b", "main", str(self.remote))
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release@example.invalid")
        self.git("remote", "add", "origin", str(self.remote))
        (self.project / "scripts").mkdir()
        shutil.copyfile(Path(__file__).with_name("release.zsh"), self.project / "scripts/release.zsh")
        with (self.project / "Info.plist").open("wb") as output:
            plistlib.dump({"CFBundleShortVersionString": "0.2.1", "CFBundleVersion": "3"}, output)
        self.git("add", ".")
        self.git("commit", "-qm", "Initial version")
        self.git("push", "-q", "origin", "main")
        self.base = self.git("rev-parse", "HEAD")
        commands = root / "commands"
        commands.mkdir()
        (commands / "git").write_text("""#!/bin/zsh
if [[ "$1 $2 $3" == 'remote get-url origin' ]]; then
  print 'https://github.com/example/release-test.git'
else
  exec /usr/bin/git "$@"
fi
""")
        (commands / "gh").write_text("""#!/bin/zsh
print -r -- "$*" >> "$RELEASE_TEST_LOG"
case "$1 $2" in
  'auth status') exit 0 ;;
  'run list') print 42 ;;
  'run watch')
    [[ "${FAIL_CI:-0}" == 0 ]] || exit 1
    if [[ "${MOVE_REMOTE:-0}" == 1 ]]; then
      /usr/bin/git --git-dir "$RELEASE_TEST_REMOTE" update-ref refs/heads/main "$RELEASE_TEST_BASE"
    fi
    ;;
  'run view') print "${CI_CONCLUSION:-success}" ;;
  *) exit 2 ;;
esac
""")
        for command in commands.iterdir():
            command.chmod(0o755)
        self.log = root / "gh.log"
        self.environment.update(PATH=f"{commands}:/usr/bin:/bin:/usr/sbin:/sbin",
                                RELEASE_TEST_LOG=str(self.log), RELEASE_TEST_REMOTE=str(self.remote),
                                RELEASE_TEST_BASE=self.base)

    def git(self, *arguments):
        result = subprocess.run(["/usr/bin/git", *arguments], cwd=self.project, env=self.environment,
                                text=True, capture_output=True, check=True)
        return result.stdout.strip()

    def release(self, version="0.2.2", **environment):
        return subprocess.run(["/bin/zsh", "scripts/release.zsh", version], cwd=self.project,
                              env=dict(self.environment, **environment), text=True, capture_output=True,
                              timeout=30)

    def plist(self):
        with (self.project / "Info.plist").open("rb") as source:
            return plistlib.load(source)

    def assert_no_release_tag(self):
        self.assertEqual(self.git("ls-remote", "origin", "refs/tags/v0.2.2"), "")
        self.assertEqual(self.git("tag", "--list", "v0.2.2"), "")

    def test_release_bumps_versions_and_tags_the_commit_checked_by_ci(self):
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.plist(), {"CFBundleShortVersionString": "0.2.2", "CFBundleVersion": "4"})
        commit = self.git("rev-parse", "HEAD")
        remote_tag = self.git("ls-remote", "origin", "refs/tags/v0.2.2^{}")
        self.assertEqual(remote_tag.split()[0], commit)
        self.assertIn(f"--commit {commit}", self.log.read_text())
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_ci_failure_can_be_retried_without_another_version_bump(self):
        self.assertNotEqual(self.release(FAIL_CI="1").returncode, 0)
        self.assert_no_release_tag()
        commit = self.git("rev-parse", "HEAD")
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), commit)
        self.assertEqual(self.plist()["CFBundleVersion"], "4")

    def test_dirty_checkout_and_other_branch_are_rejected(self):
        unfinished = self.project / "unfinished.txt"
        unfinished.write_text("work in progress")
        self.assertNotEqual(self.release().returncode, 0)
        unfinished.unlink()
        self.git("switch", "-qc", "feature")
        self.assertNotEqual(self.release().returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.base)
        self.assertEqual(self.plist()["CFBundleVersion"], "3")
        self.assert_no_release_tag()

    def test_invalid_or_older_version_is_rejected(self):
        for version in ["invalid", "0.02.2", "0.2.0"]:
            with self.subTest(version=version):
                self.assertNotEqual(self.release(version).returncode, 0)
                self.assertEqual(self.git("rev-parse", "HEAD"), self.base)
                self.assertEqual(self.plist()["CFBundleVersion"], "3")

    def test_existing_remote_tag_is_not_replaced(self):
        self.git("tag", "v0.2.2")
        self.git("push", "origin", "refs/tags/v0.2.2")
        self.assertNotEqual(self.release().returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.base)
        self.assertEqual(self.git("ls-remote", "origin", "refs/tags/v0.2.2").split()[0], self.base)

    def test_remote_main_change_or_non_successful_ci_prevents_tagging(self):
        self.assertNotEqual(self.release(CI_CONCLUSION="skipped").returncode, 0)
        self.assert_no_release_tag()
        self.assertNotEqual(self.release(MOVE_REMOTE="1").returncode, 0)
        self.assert_no_release_tag()


if __name__ == "__main__":
    unittest.main()
