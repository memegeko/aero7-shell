#!/usr/bin/env bash

if [[ -n "${AERO7_PLASMA_LOADED:-}" ]]; then
  return 0
fi
AERO7_PLASMA_LOADED=1

aero7_plasma_root_path() {
  local path="$1"
  printf '%s%s\n' "${AERO7_TEST_ROOT:-}" "$path"
}

aero7_qdbus_command() {
  if aero7_have qdbus6; then
    printf 'qdbus6\n'
    return 0
  fi
  if aero7_have qdbus-qt6; then
    printf 'qdbus-qt6\n'
    return 0
  fi
  if aero7_have qdbus; then
    printf 'qdbus\n'
    return 0
  fi
  return 1
}

aero7_graphical_session_available() {
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

aero7_kwriteconfig_user() {
  local args=("$@")
  if ! aero7_have kwriteconfig6; then
    aero7_warn "kwriteconfig6 is unavailable; cannot preseed Plasma config ${args[*]}."
    return 1
  fi
  aero7_user_run kwriteconfig6 "${args[@]}"
}

aero7_kwriteconfig_root() {
  local args=("$@")
  if ! aero7_have kwriteconfig6; then
    aero7_warn "kwriteconfig6 is unavailable; cannot write root Plasma config ${args[*]}."
    return 1
  fi
  aero7_sudo_run kwriteconfig6 "${args[@]}"
}

aero7_plasma_wayland_session_files() {
  local dir
  dir="$(aero7_plasma_root_path /usr/share/wayland-sessions)"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -type f -name '*.desktop' -print
}

aero7_validate_plasma_wayland_session() {
  local session
  while IFS= read -r session; do
    if grep -Eiq 'Name=.*Plasma|Exec=.*startplasma-wayland|X-KDE-PluginInfo-Name=.*plasma' "$session"; then
      return 0
    fi
  done < <(aero7_plasma_wayland_session_files)
  return 1
}

aero7_find_atp_wayland_session() {
  local dir candidate session
  dir="$(aero7_plasma_root_path /usr/share/wayland-sessions)"
  [[ -d "$dir" ]] || return 1
  for candidate in aerothemeplasma.desktop aerothemeplasmawayland.desktop; do
    if [[ -f "$dir/$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  session="$(find "$dir" -maxdepth 1 -type f -iname '*aero*.desktop' -printf '%f\n' | sort | head -n 1)"
  [[ -n "$session" ]] || return 1
  printf '%s\n' "$session"
}

aero7_lookandfeel_available() {
  local id="$1"
  [[ -d "$(aero7_plasma_root_path "/usr/share/plasma/look-and-feel/$id")" ]] && return 0
  if aero7_have plasma-apply-lookandfeel; then
    plasma-apply-lookandfeel --list 2>/dev/null | grep -Fqi "$id" && return 0
  fi
  if aero7_have lookandfeeltool; then
    lookandfeeltool --list 2>/dev/null | grep -Fqi "$id" && return 0
  fi
  return 1
}

aero7_apply_lookandfeel_id() {
  local id="$1"
  if aero7_have plasma-apply-lookandfeel; then
    aero7_user_run plasma-apply-lookandfeel -a "$id"
    return $?
  fi
  if aero7_have lookandfeeltool; then
    aero7_user_run lookandfeeltool -a "$id"
    return $?
  fi
  return 1
}

aero7_preseed_atp_user_config() {
  if aero7_dry_run; then
    aero7_info "Would preseed AeroThemePlasma user configuration."
    return 0
  fi

  aero7_kwriteconfig_user --file kdeglobals --group Sounds --key Theme "Windows 7" || return 0
  aero7_kwriteconfig_user --file kdeglobals --group General --key AccentColor "0,0,0,0" || true
  aero7_kwriteconfig_user --file kdeglobals --group General --key accentColorFromWallpaper --type bool false || true
  aero7_kwriteconfig_user --file kdeglobals --group General --key ColorScheme Aero || true
  aero7_kwriteconfig_user --file kdeglobals --group Icons --key Theme "Windows 7 Aero" || true
  aero7_kwriteconfig_user --file kdeglobals --group KDE --key widgetStyle kvantum || true

  aero7_kwriteconfig_user --file plasmarc --group Theme --key name Seven-Black || true

  aero7_kwriteconfig_user --file kcminputrc --group Mouse --key cursorTheme aero-drop || true
  aero7_kwriteconfig_user --file kcminputrc --group Mouse --key cursorSize 32 || true

  aero7_kwriteconfig_user --file kvantum.kvconfig --group General --key theme Windows7Aero || true
  aero7_kwriteconfig_user --file ksplashrc --group KSplash --key Theme authui7 || true
  aero7_kwriteconfig_user --file kscreenlockerrc --group Daemon --key LockGrace 0 || true
  aero7_kwriteconfig_user --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file:///usr/share/sddm/themes/sddm-theme-mod/bgtexture.jpg" || true
  aero7_kwriteconfig_user --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key PreviewImage "file:///usr/share/sddm/themes/sddm-theme-mod/bgtexture.jpg" || true
  aero7_kwriteconfig_user --file ksmserverrc --group General --key confirmLogout --type bool false || true
  aero7_kwriteconfig_user --file klaunchrc --group FeedbackStyle --key BusyCursor --type bool false || true
  aero7_kwriteconfig_user --file klaunchrc --group BusyCursorSettings --key Bouncing --type bool false || true
  aero7_kwriteconfig_user --file klaunchrc --group BusyCursorSettings --key Blinking --type bool false || true

  aero7_kwriteconfig_user --file kwinrc --group Outline --key QmlPath aeroshell/outline/plasma/outline.qml || true
  aero7_kwriteconfig_user --file kwinrc --group WindowSwitcher --key LayoutName thumbnail_aero || true
  aero7_kwriteconfig_user --file kwinrc --group TabBox --key ShowDesktopMode 1 || true
  aero7_kwriteconfig_user --file kwinrc --group TabBox --key LayoutName thumbnail_aero || true
  aero7_kwriteconfig_user --file kwinrc --group TabBoxAlternative --key ShowDesktopMode 1 || true
  aero7_kwriteconfig_user --file kwinrc --group TabBoxAlternative --key LayoutName flip3d || true
  aero7_kwriteconfig_user --file kwinrc --group MouseBindings --key CommandTitlebarWheel Nothing || true
  aero7_kwriteconfig_user --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft M || true
  aero7_kwriteconfig_user --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight H_IAX || true
  aero7_kwriteconfig_user --file kwinrc --group org.kde.kdecoration2 --key library org.smod.smod || true
  aero7_kwriteconfig_user --file kwinrc --group org.kde.kdecoration2 --key theme SMOD || true

  local effect
  for effect in smodpeekscript minimizeall aeroglassblur aeroglide smodglow smodpeekeffect libkwin_effect_smodsnap launchfeedback fadingpopupsaero squashaero dimscreenaero aeroshell-thumbnails; do
    aero7_kwriteconfig_user --file kwinrc --group Plugins --key "${effect}Enabled" --type bool true || true
  done
  for effect in blur contrast login logout maximize scale squash slide fade slidingpopups slidingnotifications dialogparent fadingpopups windowaperture; do
    aero7_kwriteconfig_user --file kwinrc --group Plugins --key "${effect}Enabled" --type bool false || true
  done
}

aero7_mark_atp_ootb_complete() {
  if aero7_dry_run; then
    aero7_info "Would mark AeroThemePlasma first-time wizard as already applied."
    return 0
  fi
  aero7_kwriteconfig_user --file aerothemeplasmarc --group OOTB --key wizardRun --type bool true || true
}

aero7_apply_atp_session_tools() {
  if aero7_dry_run; then
    aero7_info "Would run AeroThemePlasma session apply helpers where available."
    return 0
  fi

  if aero7_graphical_session_available; then
    if aero7_have kvantummanager; then
      aero7_user_run kvantummanager --set Windows7Aero || aero7_warn "Could not apply the Windows7Aero Kvantum theme automatically."
    fi
    if aero7_have plasma-apply-cursortheme; then
      aero7_user_run plasma-apply-cursortheme aero-drop --size 32 || aero7_warn "Could not apply the Aero cursor theme automatically."
    fi
  else
    aero7_info "No graphical session detected; live Kvantum and cursor apply helpers will take effect from preseeded config at next login."
  fi

  if aero7_have aeroshell_update_default_rules; then
    aero7_user_run aeroshell_update_default_rules aeroshell.rules || aero7_warn "Could not update AeroShell default KWin rules automatically."
  fi

  local qdbus_cmd
  if aero7_graphical_session_available && qdbus_cmd="$(aero7_qdbus_command)"; then
    aero7_user_run "$qdbus_cmd" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
}

aero7_apply_plasma_theme() {
  if aero7_dry_run; then
    aero7_info "Would apply AeroThemePlasma theme where available."
    return 0
  fi

  aero7_preseed_atp_user_config
  aero7_mark_atp_ootb_complete

  local id found=0 applied=0
  for id in authui7 org.aerothemeplasma.desktop; do
    if aero7_lookandfeel_available "$id"; then
      found=1
      if aero7_graphical_session_available; then
        if aero7_apply_lookandfeel_id "$id"; then
          applied=1
        else
          aero7_warn "Could not apply AeroThemePlasma look-and-feel package: $id"
        fi
      else
        aero7_info "AeroThemePlasma look-and-feel package $id is installed; preseeded config will take effect at next login."
      fi
      break
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    aero7_warn "No AeroThemePlasma look-and-feel package was available to apply."
  elif [[ "$applied" -eq 0 ]] && aero7_graphical_session_available; then
    aero7_warn "AeroThemePlasma look-and-feel package was found but could not be applied to the live session."
  fi
  aero7_apply_atp_session_tools
}

aero7_apply_plasma_layout() {
  if aero7_dry_run; then
    aero7_info "Would apply an Aero7 bottom-panel layout using Plasma scripting."
    return 0
  fi

  local script="$AERO7_CACHE_DIR/aero7-layout.js"
  aero7_user_run install -d -m 0755 "$AERO7_CACHE_DIR"
  cat >"$script" <<'EOF'
var panels = panels();
for (var i = 0; i < panels.length; i++) {
  if (panels[i].location == "bottom") {
    panels[i].height = 44;
  }
}
var panel = new Panel;
panel.location = "bottom";
panel.height = 44;
panel.addWidget("org.kde.plasma.kickoff");
panel.addWidget("org.kde.plasma.icontasks");
panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
EOF
  chown "$AERO7_USER:$AERO7_USER" "$script" 2>/dev/null || true
  aero7_state_append "modified_user_files" "$script"

  local qdbus_cmd
  if ! aero7_graphical_session_available; then
    aero7_info "No graphical session detected; Plasma layout script was staged for the next desktop session."
    aero7_state_set "logout_recommended" "yes"
  elif qdbus_cmd="$(aero7_qdbus_command)"; then
    aero7_user_run "$qdbus_cmd" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$script")" || {
      aero7_warn "Plasma layout script could not be applied. Log out and apply manually after installation."
      aero7_state_set "logout_recommended" "yes"
    }
  else
    aero7_warn "qdbus6/qdbus is unavailable; cannot apply Plasma layout automatically."
    aero7_state_set "logout_recommended" "yes"
  fi
}

aero7_find_sddm_aero_theme() {
  local theme_dir
  theme_dir="$(aero7_plasma_root_path /usr/share/sddm/themes)"
  [[ -d "$theme_dir" ]] || return 1
  if [[ -d "$theme_dir/sddm-theme-mod" ]]; then
    printf 'sddm-theme-mod\n'
    return 0
  fi
  find "$theme_dir" -maxdepth 1 -mindepth 1 -type d -iname '*aero*' -printf '%f\n' | sort | head -n 1
}

aero7_configure_default_cursor_theme() {
  if aero7_dry_run; then
    aero7_info "Would set the default cursor theme to aero-drop."
    return 0
  fi
  aero7_sudo_run install -d -m 0755 /usr/share/icons/default
  if aero7_have kwriteconfig6; then
    aero7_kwriteconfig_root --file /usr/share/icons/default/index.theme --group "Icon Theme" --key Inherits aero-drop || true
  else
    printf '[Icon Theme]\nInherits=aero-drop\n' | aero7_write_root_text /usr/share/icons/default/index.theme 0644
  fi
  aero7_state_append "modified_files" "/usr/share/icons/default/index.theme"
}

aero7_select_sddm_wayland_session() {
  local session
  session="$(aero7_find_atp_wayland_session || true)"
  [[ -n "$session" ]] || return 0

  if aero7_dry_run; then
    aero7_info "Would select SDDM default session: $session."
    return 0
  fi
  aero7_sudo_run install -d -m 0755 /var/lib/sddm
  aero7_kwriteconfig_root --file /var/lib/sddm/state.conf --group Last --key Session "$session" || return 0
  aero7_kwriteconfig_root --file /var/lib/sddm/state.conf --group Last --key User "$AERO7_USER" || true
  aero7_state_append "modified_files" "/var/lib/sddm/state.conf"
}

aero7_validate_sddm_dropin() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  grep -q '^\[General\]' "$file" || return 1
  grep -q '^DisplayServer=wayland$' "$file" || return 1
  grep -q '^GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell$' "$file" || return 1
  grep -q '^\[Wayland\]' "$file" || return 1
  grep -q '^CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1$' "$file" || return 1
  ! grep -Eiq 'AutoLogin|User=|Session=.*x11' "$file"
}

aero7_configure_sddm() {
  local theme=""
  theme="$(aero7_find_sddm_aero_theme || true)"

  if [[ -z "$theme" ]]; then
    aero7_warn "No Aero SDDM theme found; leaving Theme.Current unset."
  fi

  if aero7_dry_run; then
    aero7_info "Would write /etc/sddm.conf.d/aero7-shell.conf and enable SDDM."
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f -- "$tmp"' RETURN
  {
    printf '[General]\n'
    printf 'DisplayServer=wayland\n'
    printf 'GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell\n\n'
    printf '[Wayland]\n'
    printf 'CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1\n\n'
    printf '[Theme]\n'
    if [[ -n "$theme" ]]; then
      printf 'Current=%s\n' "$theme"
    fi
    printf 'CursorTheme=aero-drop\n'
    printf 'CursorSize=32\n'
  } >"$tmp"
  aero7_validate_sddm_dropin "$tmp" || aero7_die "Generated SDDM drop-in failed validation."
  if [[ -f /etc/sddm.conf.d/aero7-shell.conf ]]; then
    aero7_replace_file_safely /etc/sddm.conf.d/aero7-shell.conf "$tmp" "sddm" "aero7_validate_sddm_dropin"
  else
    aero7_sudo_run install -D -m 0644 "$tmp" /etc/sddm.conf.d/aero7-shell.conf
    aero7_state_append "modified_files" "/etc/sddm.conf.d/aero7-shell.conf"
  fi
  rm -f -- "$tmp"
  trap - RETURN
  aero7_configure_default_cursor_theme
  aero7_select_sddm_wayland_session
  aero7_mark_atp_ootb_complete
  aero7_systemctl_enable sddm.service
}
