#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo"

fail() {
  printf 'test-common: %s\n' "$*" >&2
  exit 1
}

while IFS= read -r file; do
  bash -n "$file" || fail "syntax failed: $file"
done < <(find . -type f \( -name '*.sh' -o -path './commands/*' -o -name 'install.sh' -o -name 'bootstrap.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) | sort)

for file in bootstrap.sh install.sh update.sh uninstall.sh commands/aero7 commands/aero7-dir commands/aero7-ipconfig commands/aero7-systeminfo commands/aero7-winver; do
  [[ -x "$file" ]] || fail "expected executable bit: $file"
done

forbidden_brand="$(printf '%s%s' 'Kes' 'cOS')"
forbidden_lower="$(printf '%s%s' 'ke' 'sk')"
forbidden_home="$(printf '/home/%s' 'geko')"
if grep -RInE --exclude-dir=.git --exclude-dir=test-results --exclude='test-common.sh' "$forbidden_brand|$forbidden_lower|$forbidden_home" .; then
  fail "found prohibited external branding or hardcoded home path"
fi

if grep -RInE 'aerothemeplasma-desktop-x11-git|aeroshell-kwin-components-x11-git|aeroshell-smodglow-x11-git|kwin-x11|plasma-x11-session' config; then
  fail "prohibited X11 package appeared in install config"
fi

if grep -RInE 'userChrome|Geckium|browser.*theme.*install|chrome/user' lib stages commands modules config; then
  fail "browser theming code appeared in executable paths"
fi

if find assets -type f \( -iname '*windows*' -o -iname 'usertile*.bmp' -o -iname '*.dll' -o -iname '*.exe' -o -iname '*.ttf' -o -iname '*.ico' -o -iname '*.wav' \) | grep -q .; then
  find assets -type f \( -iname '*windows*' -o -iname 'usertile*.bmp' -o -iname '*.dll' -o -iname '*.exe' -o -iname '*.ttf' -o -iname '*.ico' -o -iname '*.wav' \)
  fail "found prohibited or unlicensed Microsoft-style asset names"
fi

while IFS= read -r asset; do
  case "$asset" in
    assets/README.md|assets/wallpapers/README.md) continue ;;
  esac
  grep -Fq "\`$asset\`" docs/ASSET-LICENSING.md || fail "asset lacks licensing entry: $asset"
done < <(find assets -type f | sort)

export AERO7_PROJECT_ROOT="$repo"
source "$repo/lib/common.sh"
AERO7_ROOT="$repo"
source "$repo/lib/assets.sh"
preferred_wallpaper="$(aero7_preferred_wallpaper_source)"
[[ "$preferred_wallpaper" == "$repo/assets/wallpapers/aero_bg_1.png" ]] || fail "wallpaper resolver picked wrong default: $preferred_wallpaper"
! aero7_wallpaper_is_allowed "$repo/assets/wallpapers/README.md" || fail "wallpaper README was allowed as an installable wallpaper"
for wallpaper in "$repo"/assets/wallpapers/aero_bg_1.png "$repo"/assets/wallpapers/aero_bg_2.jpeg "$repo"/assets/wallpapers/aero_bg_3.jpg; do
  aero7_wallpaper_is_allowed "$wallpaper" || fail "approved wallpaper was rejected: $wallpaper"
done
! aero7_wallpaper_is_allowed "$repo/assets/wallpapers/windows-original.jpg" || fail "unapproved wallpaper was allowed"
aero7_avatar_is_allowed "$repo/assets/avatars/aero7-user.png" || fail "safe avatar was rejected"
! aero7_avatar_is_allowed "$repo/assets/avatars/usertile10.bmp" || fail "Windows usertile avatar was allowed"

printf 'test-common: ok\n'
