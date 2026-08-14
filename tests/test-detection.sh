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
cp "$updated" "$tmp/grub/etc/default/grub"
AERO7_TEST_ROOT="$tmp/grub"
aero7_bootloader_config_has_kernel_params quiet splash || fail "GRUB helper did not detect Plymouth boot params"

entry_updated="$tmp/entry-updated"
aero7_update_systemd_boot_entry_file "$repo/tests/fixtures/arch.conf" "$entry_updated" quiet splash
grep -q '^options .* quiet splash$' "$entry_updated" || fail "systemd-boot parameter merge failed"
cp "$entry_updated" "$tmp/systemd/boot/loader/entries/arch.conf"
AERO7_TEST_ROOT="$tmp/systemd"
aero7_bootloader_config_has_kernel_params quiet splash || fail "systemd-boot helper did not detect Plymouth boot params"

mkdir -p "$tmp/uki/etc/kernel" "$tmp/uki/boot/loader/entries"
cp "$repo/tests/fixtures/loader.conf" "$tmp/uki/boot/loader/loader.conf"
printf 'root=PARTUUID=test rw\n' >"$tmp/uki/etc/kernel/cmdline"
uki_updated="$tmp/uki-updated"
aero7_update_kernel_cmdline_file "$tmp/uki/etc/kernel/cmdline" "$uki_updated" quiet splash
grep -Fxq 'root=PARTUUID=test rw quiet splash' "$uki_updated" || fail "UKI kernel parameter merge failed"
cp "$uki_updated" "$tmp/uki/etc/kernel/cmdline"
AERO7_TEST_ROOT="$tmp/uki"
aero7_bootloader_config_has_kernel_params quiet splash || fail "UKI helper did not detect Plymouth boot params"

updated_hooks="$(aero7_mkinitcpio_hooks_with_plymouth 'HOOKS=(base udev autodetect microcode modconf block filesystems fsck)')"
[[ "$updated_hooks" == 'HOOKS=(base udev autodetect microcode modconf kms plymouth block filesystems fsck)' ]] || fail "mkinitcpio hook insertion failed: $updated_hooks"

mkdir -p "$tmp/mk/etc"
cp "$repo/tests/fixtures/mkinitcpio.conf" "$tmp/mk/etc/mkinitcpio.conf"
AERO7_TEST_ROOT="$tmp/mk"
[[ "$(aero7_detect_initramfs)" == "mkinitcpio" ]] || fail "mkinitcpio detection failed"
aero7_update_mkinitcpio_file "$repo/tests/fixtures/mkinitcpio.conf" "$tmp/mk/etc/mkinitcpio.conf"
aero7_initramfs_config_has_plymouth || fail "mkinitcpio helper did not detect Plymouth hook"

mkdir -p "$tmp/bin" "$tmp/mk/boot"
# shellcheck disable=SC2016 # Preserve $1 for the generated test executable.
printf '#!/usr/bin/env bash\ncat -- "$1"\n' >"$tmp/bin/lsinitcpio"
chmod +x "$tmp/bin/lsinitcpio"
original_path="$PATH"
PATH="$tmp/bin:$PATH"
printf 'usr/bin/plymouthd\n' >"$tmp/mk/boot/initramfs-linux.img"
aero7_initramfs_image_contains_plymouth || fail "initramfs helper did not detect Plymouth in a regular image"

mkdir -p "$tmp/uki-image/efi/EFI/Linux"
printf 'hooks/plymouth\n' >"$tmp/uki-image/efi/EFI/Linux/aero7.efi"
AERO7_TEST_ROOT="$tmp/uki-image"
aero7_initramfs_image_contains_plymouth || fail "initramfs helper did not detect Plymouth in a UKI on /efi"
PATH="$original_path"

mkdir -p "$tmp/dr/etc/dracut.conf.d"
cp "$repo/tests/fixtures/dracut.conf" "$tmp/dr/etc/dracut.conf"
AERO7_TEST_ROOT="$tmp/dr"
[[ "$(aero7_detect_initramfs)" == "dracut" ]] || fail "dracut detection failed"
printf 'add_dracutmodules+=" plymouth "\n' >"$tmp/dr/etc/dracut.conf.d/aero7-plymouth.conf"
aero7_initramfs_config_has_plymouth || fail "dracut helper did not detect Plymouth drop-in"

plymouth_source="$tmp/plymouthd.conf"
plymouth_updated="$tmp/plymouthd-updated.conf"
cat >"$plymouth_source" <<'EOF'
[Daemon]
Theme=spinner
ShowDelay=7
DeviceTimeout=8
EOF
aero7_update_plymouth_config_file "$plymouth_source" "$plymouth_updated"
aero7_validate_plymouth_config "$plymouth_updated" || fail "Plymouth immediate-show config did not validate"
grep -Fxq 'Theme=spinner' "$plymouth_updated" || fail "Plymouth config update lost the selected theme"
grep -Fxq 'DeviceTimeout=8' "$plymouth_updated" || fail "Plymouth config update lost unrelated settings"
[[ "$(grep -Fxc 'ShowDelay=0' "$plymouth_updated")" -eq 1 ]] || fail "Plymouth config update did not set one immediate show delay"

plymouth_dropin="$tmp/aero7-hold.conf"
printf '[Service]\nExecStartPre=/usr/bin/sleep 5\n' >"$plymouth_dropin"
AERO7_PLYMOUTH_CONF="$plymouth_updated"
AERO7_PLYMOUTH_HOLD_DROPIN="$plymouth_dropin"
aero7_plymouth_visibility_configured || fail "Plymouth five-second hold was not detected"
unset AERO7_PLYMOUTH_CONF AERO7_PLYMOUTH_HOLD_DROPIN

plymouth_source="$tmp/plymouth-vista-source"
mkdir -p "$plymouth_source/src" "$plymouth_source/images"
printf 'MIT\n' >"$plymouth_source/LICENSE"
printf 'ModuleName=script\n' >"$plymouth_source/PlymouthVista.plymouth"
printf '#!/usr/bin/env bash\n' >"$plymouth_source/compile.sh"
printf '#!/usr/bin/env bash\n' >"$plymouth_source/pv_conf.sh"
chmod +x "$plymouth_source/compile.sh" "$plymouth_source/pv_conf.sh"
printf 'SevenBootScreenNew\n' >"$plymouth_source/src/boot7.sp"
printf 'main\n' >"$plymouth_source/src/main.sp"
printf 'frame\n' >"$plymouth_source/images/flag0.png"
printf 'frame\n' >"$plymouth_source/images/flag104.png"
aero7_validate_plymouth_vista_source "$plymouth_source" || fail "PlymouthVista source fixture did not validate"

plymouth_theme="$tmp/plymouth-vista-theme"
mkdir -p "$plymouth_theme/images"
printf 'MIT\n' >"$plymouth_theme/LICENSE"
printf 'ModuleName=script\n' >"$plymouth_theme/PlymouthVista.plymouth"
printf 'global.UseLegacyBootScreen = 0;\nglobal.AuthuiStyle = "7";\n' >"$plymouth_theme/PlymouthVista.script"
printf 'frame\n' >"$plymouth_theme/images/flag0.png"
printf 'frame\n' >"$plymouth_theme/images/flag104.png"
AERO7_PLYMOUTH_THEME_DIR="$plymouth_theme"
aero7_validate_installed_plymouth_vista_theme || fail "installed PlymouthVista fixture did not validate"
unset AERO7_PLYMOUTH_THEME_DIR

printf 'test-detection: ok\n'
