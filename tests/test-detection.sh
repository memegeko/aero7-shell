#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export AERO7_PROJECT_ROOT="$repo"

source "$repo/lib/common.sh"
source "$repo/lib/bootloader.sh"
source "$repo/lib/initramfs.sh"

fail() {
  printf 'test-detection: %s\n' "$*" >&2
  exit 1
}

tmp="$(mktemp -d)"
cleanup() {
  rm -rf -- "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/grub/etc/default" "$tmp/grub/boot/grub"
cp "$repo/tests/fixtures/grub-default" "$tmp/grub/etc/default/grub"
cp "$repo/tests/fixtures/grub.cfg" "$tmp/grub/boot/grub/grub.cfg"
AERO7_TEST_ROOT="$tmp/grub"
[[ "$(aero7_detect_bootloader)" == "grub" ]] || fail "GRUB detection failed"

mkdir -p "$tmp/systemd/boot/loader/entries"
cp "$repo/tests/fixtures/loader.conf" "$tmp/systemd/boot/loader/loader.conf"
cp "$repo/tests/fixtures/arch.conf" "$tmp/systemd/boot/loader/entries/arch.conf"
AERO7_TEST_ROOT="$tmp/systemd"
[[ "$(aero7_detect_bootloader)" == "systemd-boot" ]] || fail "systemd-boot detection failed"

mkdir -p "$tmp/ambiguous/etc/default" "$tmp/ambiguous/boot/grub" "$tmp/ambiguous/boot/loader/entries"
cp "$repo/tests/fixtures/grub-default" "$tmp/ambiguous/etc/default/grub"
cp "$repo/tests/fixtures/loader.conf" "$tmp/ambiguous/boot/loader/loader.conf"
AERO7_TEST_ROOT="$tmp/ambiguous"
[[ "$(aero7_detect_bootloader)" == "ambiguous" ]] || fail "ambiguous bootloader detection failed"

updated="$tmp/grub-updated"
aero7_update_grub_cmdline_file "$repo/tests/fixtures/grub-default" "$updated" quiet splash
grep -q 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"' "$updated" || fail "GRUB parameter merge failed"

entry_updated="$tmp/entry-updated"
aero7_update_systemd_boot_entry_file "$repo/tests/fixtures/arch.conf" "$entry_updated" quiet splash
grep -q '^options .* quiet splash$' "$entry_updated" || fail "systemd-boot parameter merge failed"

hooks="$(aero7_mkinitcpio_hooks_with_plymouth 'HOOKS=(base udev autodetect microcode modconf block filesystems fsck)')"
[[ "$hooks" == 'HOOKS=(base udev autodetect microcode modconf kms plymouth block filesystems fsck)' ]] || fail "mkinitcpio hook insertion failed: $hooks"

mkdir -p "$tmp/mk/etc"
cp "$repo/tests/fixtures/mkinitcpio.conf" "$tmp/mk/etc/mkinitcpio.conf"
AERO7_TEST_ROOT="$tmp/mk"
[[ "$(aero7_detect_initramfs)" == "mkinitcpio" ]] || fail "mkinitcpio detection failed"

mkdir -p "$tmp/dr/etc/dracut.conf.d"
cp "$repo/tests/fixtures/dracut.conf" "$tmp/dr/etc/dracut.conf"
AERO7_TEST_ROOT="$tmp/dr"
[[ "$(aero7_detect_initramfs)" == "dracut" ]] || fail "dracut detection failed"

printf 'test-detection: ok\n'

