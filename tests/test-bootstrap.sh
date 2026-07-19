#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
  printf 'test-bootstrap: %s\n' "$*" >&2
  exit 1
}

main_output="$(AERO7_BOOTSTRAP_PRINT_URLS=1 bash "$repo/bootstrap.sh")"
[[ "$main_output" == *"repository=memegeko/aero_desktop"* ]] || fail "default repository is wrong"
[[ "$main_output" == *"ref=main"* ]] || fail "default ref is not main"
[[ "$main_output" == *"archive_url=https://codeload.github.com/memegeko/aero_desktop/tar.gz/refs/heads/main"* ]] || fail "main archive URL is wrong"
[[ "$main_output" == *"checksum_required=0"* ]] || fail "main branch should not require release checksum by default"

release_output="$(AERO7_BOOTSTRAP_PRINT_URLS=1 AERO7_VERSION=v0.1.0 bash "$repo/bootstrap.sh")"
[[ "$release_output" == *"archive_url=https://github.com/memegeko/aero_desktop/releases/download/v0.1.0/aero7-shell-v0.1.0.tar.gz"* ]] || fail "release archive URL is wrong"
[[ "$release_output" == *"checksum_required=1"* ]] || fail "release mode should require checksum"

branch_output="$(AERO7_BOOTSTRAP_PRINT_URLS=1 AERO7_BRANCH=dev-test bash "$repo/bootstrap.sh")"
[[ "$branch_output" == *"ref=dev-test"* ]] || fail "AERO7_BRANCH compatibility broke"
[[ "$branch_output" == *"refs/heads/dev-test"* ]] || fail "branch archive URL is wrong"

printf 'test-bootstrap: ok\n'
