# Release Workflow

Aero7-shell bootstrap downloads a tagged release archive and verifies it with `checksums.txt`. Do not publish or document an unverified archive as stable.

Build a release from a clean git worktree:

```bash
AERO7_VERSION=0.1.0 tools/build-release.sh
```

The script uses `git ls-files`, excludes generated output and local assets, writes the archive to `dist/`, and creates `dist/checksums.txt`.

Publish the first release:

1. Commit all release-ready files.
2. Tag the commit, for example `git tag -a v0.1.0 -m "Aero7-shell v0.1.0 alpha"`.
3. Run `AERO7_VERSION=v0.1.0 tools/build-release.sh`.
4. Create a GitHub release for the tag.
5. Upload `dist/aero7-shell-v0.1.0.tar.gz` and `dist/checksums.txt`.
6. Test the bootstrap command in a fresh VM.

Development branch testing can use:

```bash
AERO7_BRANCH=main bash bootstrap.sh
```

Branch mode is for development only. It still downloads and verifies `checksums.txt` from that branch and does not fall back to unchecked archives.

