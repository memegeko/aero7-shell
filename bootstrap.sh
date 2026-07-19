#!/usr/bin/env bash
set -Eeuo pipefail

AERO7_REPOSITORY="${AERO7_REPOSITORY:-memegeko/Aero7-shell}"
AERO7_VERSION="${AERO7_VERSION:-v0.1.0}"
AERO7_BRANCH="${AERO7_BRANCH:-}"
AERO7_DEBUG="${AERO7_DEBUG:-0}"

if [[ "$AERO7_DEBUG" == "1" ]]; then
  set -x
fi

bootstrap_die() {
  printf 'Aero7-shell bootstrap error: %s\n' "$*" >&2
  exit 1
}

bootstrap_have() {
  command -v "$1" >/dev/null 2>&1
}

bootstrap_is_arch() {
  [[ -r /etc/os-release ]] || return 1
  local id id_like
  id="$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)"
  id_like="$(awk -F= '$1 == "ID_LIKE" { gsub(/"/, "", $2); print $2 }' /etc/os-release)"
  [[ "$id" == "arch" || " $id_like " == *" arch "* ]]
}

bootstrap_fetch() {
  local url="$1"
  local dest="$2"
  curl -fsSL --retry 3 --connect-timeout 20 "$url" -o "$dest"
}

bootstrap_verify_checksum() {
  local archive="$1"
  local checksum_file="$2"
  local archive_base expected
  archive_base="$(basename -- "$archive")"
  expected="$(awk -v file="$archive_base" '$2 == file { print $1; exit }' "$checksum_file")"
  if [[ -z "$expected" ]]; then
    expected="$(awk 'NF >= 1 { print $1; exit }' "$checksum_file")"
  fi
  [[ -n "$expected" ]] || bootstrap_die "Checksum file did not contain a usable SHA-256 value."
  printf '%s  %s\n' "$expected" "$archive" | sha256sum -c -
}

[[ "$(id -u)" -ne 0 ]] || bootstrap_die "Do not run the bootstrapper as root."
bootstrap_is_arch || bootstrap_die "This system does not appear to be Arch Linux."

for tool in curl tar sha256sum mktemp awk; do
  bootstrap_have "$tool" || bootstrap_die "Required tool missing: $tool"
done

normal_user="${SUDO_USER:-$(id -un)}"
[[ "$normal_user" != "root" ]] || bootstrap_die "Could not determine a normal invoking user."

tmp_dir="$(mktemp -d)"
# Invoked by the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  if [[ -n "${tmp_dir:-}" && "$tmp_dir" == /tmp/* ]]; then
    rm -rf -- "$tmp_dir"
  fi
}
trap cleanup EXIT

archive="$tmp_dir/aero7-shell.tar.gz"
checksums="$tmp_dir/checksums.txt"

if [[ -n "$AERO7_BRANCH" ]]; then
  archive_url="https://github.com/${AERO7_REPOSITORY}/archive/refs/heads/${AERO7_BRANCH}.tar.gz"
  checksum_url="https://raw.githubusercontent.com/${AERO7_REPOSITORY}/${AERO7_BRANCH}/checksums.txt"
else
  archive_name="aero7-shell-${AERO7_VERSION}.tar.gz"
  archive="$tmp_dir/$archive_name"
  archive_url="https://github.com/${AERO7_REPOSITORY}/releases/download/${AERO7_VERSION}/${archive_name}"
  checksum_url="https://github.com/${AERO7_REPOSITORY}/releases/download/${AERO7_VERSION}/checksums.txt"
fi

printf 'Downloading %s...\n' "$archive_url"
bootstrap_fetch "$archive_url" "$archive" || bootstrap_die "Failed to download release archive."
bootstrap_fetch "$checksum_url" "$checksums" || bootstrap_die "Failed to download checksum file."
bootstrap_verify_checksum "$archive" "$checksums" || bootstrap_die "Archive checksum verification failed."

tar -xzf "$archive" -C "$tmp_dir"
install_script="$(find "$tmp_dir" -mindepth 2 -maxdepth 3 -type f -name install.sh | head -n 1)"
[[ -n "$install_script" ]] || bootstrap_die "Extracted archive did not contain install.sh."

set +e
bash "$install_script" "$@"
exit_code=$?
set -e
exit "$exit_code"
