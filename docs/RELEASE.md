# Release Workflow

`release` is the canonical Aero7-shell branch. Version 1.0 is feature-complete,
so subsequent releases contain bug fixes, security fixes, required platform
compatibility updates, and documentation corrections only.

When `AERO7_VERSION` is set, `bootstrap.sh` downloads a tagged release archive
and verifies it with the release's `checksums.txt`. Do not publish or document
an unverified archive as stable.

## Validation

From a clean worktree, run the complete automated suite used by CI:

```bash
find . -type f \( -name '*.sh' -o -path './commands/*' -o -name 'install.sh' -o -name 'bootstrap.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) -print0 | xargs -0 -n1 bash -n
bash tests/test-bootstrap.sh
bash tests/test-common.sh
bash tests/test-detection.sh
bash tests/test-recipes.sh
bash tests/test-ui-events.sh
python tests/test-ui-protocol.py
python tests/test-ui-pty.py
bash tests/test-ui.sh
bash tests/test-policy.sh
python -m py_compile ui/aero7_setup.py tools/ui-demo.py tests/test-ui-protocol.py tests/test-ui-pty.py
find . -type f \( -name '*.sh' -o -path './commands/*' -o -name 'install.sh' -o -name 'bootstrap.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) -print0 | xargs -0 shellcheck
```

## Build and publish

1. Commit all release-ready files on `release`.
2. Run `AERO7_VERSION=v1.0.0 tools/build-release.sh`.
3. Verify `dist/checksums.txt` with `sha256sum -c`.
4. Tag the tested commit with an annotated semantic-version tag.
5. Create a GitHub release and attach the archive plus `checksums.txt`.
6. Verify the published assets and the pinned bootstrap URL.

The builder uses `git ls-files`, excludes generated output, writes the archive
to `dist/`, and creates `dist/checksums.txt`. Branch mode remains available for
maintainer diagnostics with `AERO7_REF=release`, but tagged release mode is the
recommended public installation path.
