#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
  printf 'test-bootstrap: %s\n' "$*" >&2
  exit 1
}

default_output="$(AERO7_BOOTSTRAP_PRINT_URLS=1 bash "$repo/bootstrap.sh")"
[[ "$default_output" == *"repository=memegeko/aero7-shell"* ]] || fail "default repository is wrong"
[[ "$default_output" == *"ref=release"* ]] || fail "default ref is not release"
[[ "$default_output" == *"archive_url=https://codeload.github.com/memegeko/aero7-shell/tar.gz/refs/heads/release"* ]] || fail "release branch archive URL is wrong"
[[ "$default_output" == *"checksum_required=0"* ]] || fail "branch archives should not require release checksum by default"

release_output="$(AERO7_BOOTSTRAP_PRINT_URLS=1 AERO7_VERSION=v1.0.0 bash "$repo/bootstrap.sh")"
[[ "$release_output" == *"archive_url=https://github.com/memegeko/aero7-shell/releases/download/v1.0.0/aero7-shell-v1.0.0.tar.gz"* ]] || fail "release archive URL is wrong"
[[ "$release_output" == *"checksum_required=1"* ]] || fail "release mode should require checksum"

branch_output="$(AERO7_BOOTSTRAP_PRINT_URLS=1 AERO7_BRANCH=dev-test bash "$repo/bootstrap.sh")"
[[ "$branch_output" == *"ref=dev-test"* ]] || fail "AERO7_BRANCH compatibility broke"
[[ "$branch_output" == *"refs/heads/dev-test"* ]] || fail "branch archive URL is wrong"

printf 'test-bootstrap: ok\n'
