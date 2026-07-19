#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

version="${AERO7_VERSION:-0.1.0}"
prefix="aero7-shell-${version}"
dist_dir="$repo_root/dist"
archive="$dist_dir/${prefix}.tar.gz"
checksum="$dist_dir/checksums.txt"
tmp_dir="$(mktemp -d)"

cleanup() {
  if [[ -n "${tmp_dir:-}" && "$tmp_dir" == /tmp/* ]]; then
    rm -rf -- "$tmp_dir"
  fi
}
trap cleanup EXIT

die() {
  printf 'build-release: %s\n' "$*" >&2
  exit 1
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "release builds require a git repository so only tracked files are archived."
git diff --quiet || die "working tree has unstaged changes; commit or stash before building a release."
git diff --cached --quiet || die "index has staged changes; commit or unstage before building a release."

mkdir -p "$dist_dir"
rm -f -- "$archive" "$checksum"
mkdir -p "$tmp_dir/$prefix"

while IFS= read -r file; do
  case "$file" in
    dist/*|*.log|.git/*|*/.cache/*|*/logs/*|*/state/*|*/backups/*)
      continue
      ;;
    assets/wallpapers/*.jpg|assets/wallpapers/*.jpeg|assets/wallpapers/*.png|assets/wallpapers/*.bmp|assets/wallpapers/*.svg|assets/avatars/usertile*.bmp)
      continue
      ;;
  esac
  mkdir -p "$tmp_dir/$prefix/$(dirname -- "$file")"
  cp -p -- "$file" "$tmp_dir/$prefix/$file"
done < <(git ls-files)

tar --sort=name \
  --mtime='UTC 2026-01-01' \
  --owner=0 --group=0 --numeric-owner \
  -C "$tmp_dir" -czf "$archive" "$prefix"

(
  cd "$dist_dir"
  sha256sum "$(basename -- "$archive")" >"$(basename -- "$checksum")"
)

printf 'Archive:  %s\n' "$archive"
printf 'Checksum: %s\n' "$checksum"
