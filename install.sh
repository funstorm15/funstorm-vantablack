#!/usr/bin/env bash
# FunStorm Vantablack: an Omarchy-style KDE Plasma 6 setup (Wayland).
# Run inside a Plasma 6 Wayland session as your normal user (not root).
#   ./install.sh            interactive: asks before every step
#   ./install.sh --yes      apply everything without asking (sudo still asks for a password)
#   ./install.sh --dry-run  show what would happen, change nothing
#   ./install.sh --undo     restore the configs saved by the last run and remove what it added
#   ./install.sh --only STEPS   comma separated: packages,files,look,kwin,shortcuts,panel,wallpaper,login,splash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/funstorm-vantablack"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
bindir="$HOME/.local/bin"
wallpapers="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers/vantablack}"
dry=0 yes=0 only=""
all_steps="packages files look kwin shortcuts panel wallpaper login splash"

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if [ "$dry" -eq 1 ]; then printf '  would run: %s\n' "$*" >&2; else "$@"; fi; }
ask()  {
    [ "$yes" -eq 1 ] || [ "$dry" -eq 1 ] && return 0
    local r; read -r -p "$1 [Y/n] " r; [[ ! "$r" =~ ^[Nn] ]]
}
want() { [ -z "$only" ] || [[ ",$only," == *",$1,"* ]]; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) yes=1 ;;
        --dry-run|-n) dry=1 ;;
        --undo) undo=1 ;;
        --only) shift; only="${1:-}"; [ -n "$only" ] || die "--only needs a list" ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
    shift
done

# ---------------------------------------------------------------- undo
backup_files=(
    "$cfg/kdeglobals" "$cfg/kwinrc" "$cfg/kwinrulesrc" "$cfg/kglobalshortcutsrc"
    "$cfg/plasmarc" "$cfg/kcminputrc" "$cfg/plasma-org.kde.plasma.desktop-appletsrc"
    "$cfg/plasmashellrc" "$cfg/inputactions/config.yaml" "$cfg/ghostty/config"
)
added_paths=(
    "$data/kwin/effects/cubeswitch" "$data/kwin/effects/zoomdesktop" "$data/kwin/effects/kwin6_effect_glitch"
    "$data/kwin/scripts/krohnkite" "$data/plasma/plasmoids/funstorm.workspaces"
    "$data/plasma/wallpapers/funstorm.reveal" "$data/plasma/plasmoids/org.kde.desktopcontainment"
    "$data/color-schemes/Vantablack.colors" "$data/funstorm-vantablack"
    "$bindir/vantablack-wallpaper" "$bindir/vantablack-wallpaper-set" "$bindir/desktop-dblclick-patch"
    "$data/applications/vantablack-wallpaper.desktop" "$cfg/autostart/desktop-dblclick-patch.desktop"
)

if [ "${undo:-0}" -eq 1 ]; then
    last="$(ls -1d "$state"/backup-* 2>/dev/null | tail -1)"
    [ -n "$last" ] || die "nothing to undo"
    say "Restoring configs from $last"
    while IFS= read -r f; do
        rel="${f#"$HOME"/}"
        if [ -e "$last/home/$rel" ]; then run mkdir -p "$(dirname "$f")"; run cp -a "$last/home/$rel" "$f"
        else run rm -f "$f"; fi
    done < "$last/files"
    for p in "${added_paths[@]}"; do [ -e "$p" ] && run rm -rf "$p"; done
    say "Restart the session (log out and in) to finish undoing."
    exit 0
fi

# ---------------------------------------------------------------- checks
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"
[ "${XDG_SESSION_TYPE:-}" = wayland ] || warn "not a Wayland session; this setup is made for Plasma 6 on Wayland"
[[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] || die "run this inside a KDE Plasma 6 session"
for t in kwriteconfig6 qdbus6 busctl; do have "$t" || die "missing $t"; done

backup() {
    [ "$dry" -eq 1 ] && return 0
    run_dir="$state/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$run_dir/home"
    printf '%s\n' "${backup_files[@]}" > "$run_dir/files"
    for f in "${backup_files[@]}"; do
        [ -e "$f" ] || continue
        rel="${f#"$HOME"/}"; mkdir -p "$run_dir/home/$(dirname "$rel")"; cp -a "$f" "$run_dir/home/$rel"
    done
    say "Backup saved to $run_dir (undo with ./install.sh --undo)"
}

kw() { run kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"; }

# Qt key code for a shortcut like "Meta+Ctrl+L" (kglobalaccel takes ints)
keycode() {
    local spec="$1" code=0 part
    IFS=+ read -ra parts <<< "$spec"
    for part in "${parts[@]}"; do
        case "$part" in
            Meta) code=$((code | 0x10000000)) ;; Ctrl) code=$((code | 0x04000000)) ;;
            Alt) code=$((code | 0x08000000)) ;;  Shift) code=$((code | 0x02000000)) ;;
            Tab) code=$((code | 0x01000001)) ;;  Return) code=$((code | 0x01000004)) ;;
            Space) code=$((code | 0x20)) ;;     Left) code=$((code | 0x01000012)) ;;
            Up) code=$((code | 0x01000013)) ;;  Right) code=$((code | 0x01000014)) ;;
            Down) code=$((code | 0x01000015)) ;; PgUp) code=$((code | 0x01000016)) ;;
            PgDown) code=$((code | 0x01000017)) ;; Screensaver) code=$((code | 0x010000ba)) ;;
            [A-Z0-9]) code=$((code | $(printf '%d' "'$part"))) ;;
            '!'|'@'|'#'|'$'|'%') code=$((code | $(printf '%d' "'$part"))) ;;
            *) die "unknown key in shortcut: $spec" ;;
        esac
    done
    echo "$code"
}

# shortcut <component> <friendly component> <action> <friendly action> [keys...]  (no keys = clear)
shortcut() {
    local comp="$1" fcomp="$2" act="$3" fact="$4"; shift 4
    local codes=()
    for k in "$@"; do codes+=("$(keycode "$k")"); done
    run busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel \
        doRegister as 4 "$comp" "$act" "$fcomp" "$fact" >/dev/null
    run busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel \
        setForeignShortcut asai 4 "$comp" "$act" "$fcomp" "$fact" "${#codes[@]}" "${codes[@]}" >/dev/null
}

# ---------------------------------------------------------------- steps
step_packages() {
    say "Packages"
    local repo_pkgs=(inter-font ttf-jetbrains-mono-nerd qt6-declarative plasma5support kdeplasma-addons python-dbus ffmpeg)
    local aur_pkgs=(darkly-bin colloid-icon-theme-git kwin-scripts-krohnkite-git plasma6-applets-appgrid
        plasma6-applets-panel-colorizer inputactions-kwin inputactions-kwin-alpm-hook)
    ask "Install repo packages: ${repo_pkgs[*]}?" && run sudo pacman -S --needed "${repo_pkgs[@]}"
    if have paru || have yay; then
        local helper; helper="$(command -v paru || command -v yay)"
        ask "Install AUR packages with ${helper##*/}: ${aur_pkgs[*]}?" && run "$helper" -S --needed "${aur_pkgs[@]}"
    else
        warn "no AUR helper (paru/yay); install these yourself: ${aur_pkgs[*]}"
    fi
}

step_files() {
    say "Effects, widgets, wallpaper plugin, scripts"
    run mkdir -p "$data/kwin/effects" "$data/kwin/scripts" "$data/plasma/plasmoids" "$data/plasma/wallpapers" \
        "$data/color-schemes" "$data/funstorm-vantablack" "$data/applications" "$cfg/autostart" "$bindir" "$cfg/inputactions"
    run cp -r "$repo/kwin/effects/cubeswitch" "$repo/kwin/effects/zoomdesktop" "$data/kwin/effects/"
    # Krohnkite: copy the packaged script and lay the Vantablack popup + icons over it
    if [ -d /usr/share/kwin/scripts/krohnkite ]; then
        run rm -rf "$data/kwin/scripts/krohnkite"
        run cp -r /usr/share/kwin/scripts/krohnkite "$data/kwin/scripts/krohnkite"
        run cp -r "$repo/kwin/scripts/krohnkite-overlay/." "$data/kwin/scripts/krohnkite/"
        # icons ship with the overlay, so skip Krohnkite's python icon installer
        run sed -i 's|^\(\s*\)source: "iconinstaller.qml"|\1active: false\n\1source: "iconinstaller.qml"|' \
            "$data/kwin/scripts/krohnkite/contents/ui/main.qml"
    else
        warn "Krohnkite not installed (kwin-scripts-krohnkite-git); tiling is skipped"
    fi
    run cp -r "$repo/plasma/plasmoids/funstorm.workspaces" "$data/plasma/plasmoids/"
    run cp -r "$repo/plasma/wallpapers/funstorm.reveal" "$data/plasma/wallpapers/"
    run cp "$repo/plasma/color-schemes/Vantablack.colors" "$data/color-schemes/"
    run cp "$repo/share/picker/picker.qml" "$repo/plasma/panel/vantablack-menu.svg" "$data/funstorm-vantablack/"
    run install -m 755 "$repo/bin/vantablack-wallpaper" "$repo/bin/vantablack-wallpaper-set" \
        "$repo/bin/desktop-dblclick-patch" "$bindir/"
    [ -f "$cfg/inputactions/config.yaml" ] && ! ask "Replace your InputActions gesture config?" || \
        run cp "$repo/inputactions/config.yaml" "$cfg/inputactions/config.yaml"
    if have ghostty || [ -d "$cfg/ghostty" ]; then
        ask "Install the Ghostty config (Vantablack colours)?" && {
            run mkdir -p "$cfg/ghostty"; run cp "$repo/ghostty/config" "$repo/ghostty/vantablack.conf" "$cfg/ghostty/"; }
    fi
    # Glitch close animation from Burn My Windows (GPL-3.0), fetched from its release
    if [ ! -d "$data/kwin/effects/kwin6_effect_glitch" ] && ask "Download the Glitch close animation (Burn My Windows)?"; then
        local tmp; tmp="$(mktemp -d)"
        if run curl -fsSL -o "$tmp/bmw.tar.gz" \
            https://github.com/Schneegans/Burn-My-Windows/releases/latest/download/burn_my_windows_kwin6.tar.gz; then
            run tar -xzf "$tmp/bmw.tar.gz" -C "$tmp"
            run cp -r "$tmp/kwin6_effect_glitch" "$data/kwin/effects/"
        else warn "could not download Burn My Windows; skipping Glitch"; fi
        rm -rf "$tmp"
    fi
    # wallpaper picker: Meta+Ctrl+Space and the "Wallpaper Picker" app entry
    if [ "$dry" -eq 0 ]; then
        cat > "$data/applications/vantablack-wallpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Wallpaper Picker
Comment=Pick a wallpaper (Omarchy style)
Exec=$bindir/vantablack-wallpaper
Icon=preferences-desktop-wallpaper
Categories=Settings;
EOF
        cat > "$cfg/autostart/desktop-dblclick-patch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Desktop double-click patch check
Exec=$bindir/desktop-dblclick-patch --restart
NoDisplay=true
X-KDE-autostart-phase=1
EOF
    fi
    run "$bindir/desktop-dblclick-patch"
    have kbuildsycoca6 && run kbuildsycoca6 >/dev/null 2>&1 || true
}

step_look() {
    say "Colours, icons, fonts, window style"
    have plasma-apply-colorscheme && run plasma-apply-colorscheme Vantablack
    have plasma-apply-desktoptheme && run plasma-apply-desktoptheme default
    [ -d /usr/share/icons/Colloid-Grey-Dark ] && run /usr/lib/plasma-changeicons Colloid-Grey-Dark
    have plasma-apply-cursortheme && run plasma-apply-cursortheme breeze_cursors
    kw kdeglobals KDE widgetStyle Darkly
    kw kdeglobals KDE AutomaticLookAndFeel false
    kw kdeglobals General font "Inter,10,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium"
    kw kdeglobals General menuFont "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kw kdeglobals General toolBarFont "Inter,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kw kdeglobals General smallestReadableFont "Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kw kdeglobals General fixed "JetBrainsMonoNL Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kw kdeglobals WM activeFont "Inter,10,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium"
    kw kwinrc org.kde.kdecoration2 library org.kde.darkly
    kw kwinrc org.kde.kdecoration2 theme Darkly
    kw kwinrc org.kde.kdecoration2 BorderSize Normal
    kw kwinrc TabBox LayoutName coverswitch
}

step_kwin() {
    say "Window manager: tiling, focus, desktops, effects, gestures"
    # Omarchy-like focus: the window under the pointer is active, no delay
    kw kwinrc Windows FocusPolicy FocusFollowsMouse
    kw kwinrc Windows NextFocusPrefersMouse true
    kw kwinrc Windows DelayFocusInterval 0
    kw kwinrc Windows ClickRaise true
    kw kwinrc Windows FocusStealingPreventionLevel 1
    kw kwinrc Windows RollOverDesktops true
    # 5 desktops in one column: KWin's own horizontal touchpad swipes then do nothing
    local n
    n="$(qdbus6 org.kde.KWin /VirtualDesktopManager org.freedesktop.DBus.Properties.Get org.kde.KWin.VirtualDesktopManager count 2>/dev/null || echo 5)"
    while [ "$n" -lt 5 ]; do
        run qdbus6 org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.createDesktop "$n" "Desktop $((n + 1))" >/dev/null
        n=$((n + 1))
    done
    run qdbus6 org.kde.KWin /VirtualDesktopManager org.freedesktop.DBus.Properties.Set org.kde.KWin.VirtualDesktopManager rows 5 >/dev/null || true
    kw kwinrc Desktops Rows 5
    # Krohnkite: spiral (dwindle) and columns (scrolling), no gaps
    local K=Script-krohnkite l
    for l in tile monocle threeColumn quarter stacked spread floating stair binaryTree cascade; do kw kwinrc $K "${l}LayoutEnabled" false; done
    kw kwinrc $K spiralLayoutEnabled true;  kw kwinrc $K spiralLayoutOrder 1
    kw kwinrc $K columnsLayoutEnabled true; kw kwinrc $K columnsLayoutOrder 2
    for l in screenGapLeft screenGapRight screenGapTop screenGapBottom screenGapBetween tileLayoutGap; do kw kwinrc $K "$l" 0; done
    kw kwinrc $K notificationDuration 700
    # effects
    kw kwinrc Plugins krohnkiteEnabled true
    kw kwinrc Plugins cubeswitchEnabled true
    kw kwinrc Plugins zoomdesktopEnabled true
    kw kwinrc Plugins kwin_gesturesEnabled true
    kw kwinrc Plugins slideEnabled false
    kw kwinrc Plugins fadedesktopEnabled false
    kw kwinrc Plugins overviewEnabled false
    kw kwinrc Plugins windowviewEnabled false
    kw kwinrc Plugins scaleEnabled false
    kw kwinrc Plugins blurEnabled true
    kw kwinrc Plugins magiclampEnabled true
    [ -d "$data/kwin/effects/kwin6_effect_glitch" ] && kw kwinrc Plugins kwin6_effect_glitchEnabled true
    # window rules: windows never open maximized (tiling skips maximized ones); Telegram can't steal focus
    if [ "$dry" -eq 0 ]; then
        local order
        order="$(kreadconfig6 --file kwinrulesrc --group General --key Order 2>/dev/null || true)"
        for r in funstorm-no-maximize funstorm-telegram-no-steal; do
            [[ ",$order," == *",$r,"* ]] || order="${order:+$order,}$r"
        done
        kw kwinrulesrc General Order "$order"
        kw kwinrulesrc General count "$(tr ',' '\n' <<< "$order" | grep -c .)"
    fi
    kw kwinrulesrc funstorm-no-maximize Description "No maximize (tiling; use Meta+F for fullscreen)"
    kw kwinrulesrc funstorm-no-maximize maximizehoriz false; kw kwinrulesrc funstorm-no-maximize maximizehorizrule 2
    kw kwinrulesrc funstorm-no-maximize maximizevert false;  kw kwinrulesrc funstorm-no-maximize maximizevertrule 2
    kw kwinrulesrc funstorm-no-maximize types 1;             kw kwinrulesrc funstorm-no-maximize wmclassmatch 0
    kw kwinrulesrc funstorm-telegram-no-steal Description "Telegram: don't steal focus or switch desktops"
    kw kwinrulesrc funstorm-telegram-no-steal wmclass telegram; kw kwinrulesrc funstorm-telegram-no-steal wmclassmatch 2
    kw kwinrulesrc funstorm-telegram-no-steal fsplevel 3;       kw kwinrulesrc funstorm-telegram-no-steal fsplevelrule 2
    run qdbus6 org.kde.KWin /KWin reconfigure >/dev/null
    for e in cubeswitch zoomdesktop kwin_gestures; do run qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$e" >/dev/null || true; done
}

step_shortcuts() {
    say "Shortcuts"
    local K=kwin F=KWin i sym=('' '!' '@' '#' '$' '%')
    for i in 1 2 3 4 5; do
        shortcut $K $F "Cube Switch to Desktop $i" "Cube Switch to Desktop $i" "Alt+$i"
        shortcut $K $F "Switch to Desktop $i" "Switch to Desktop $i"
        shortcut $K $F "Window to Desktop $i" "Window to Desktop $i" "Meta+Shift+$i" "Meta+${sym[$i]}"
        shortcut plasmashell plasmashell "activate task manager entry $i" "Activate Task Manager Entry $i"
    done
    shortcut $K $F "Cube Switch Next Desktop" "Cube Switch to Next Desktop" Alt+Tab
    shortcut $K $F "Cube Switch Toggle" "Toggle Cube (Cube Switch)" Meta+C
    shortcut $K $F "Switch to Next Desktop" "Switch to Next Desktop"
    shortcut $K $F "Switch to Previous Desktop" "Switch to Previous Desktop"
    for a in "Switch One Desktop to the Left" "Switch One Desktop Up" "Switch One Desktop to the Right" "Switch One Desktop Down"; do
        shortcut $K $F "$a" "$a"
    done
    shortcut $K $F "Walk Through Windows" "Walk Through Windows" Meta+Tab
    shortcut $K $F "Walk Through Windows (Reverse)" "Walk Through Windows (Reverse)" Meta+Shift+Tab
    shortcut $K $F "Window Close" "Close Window" Meta+W
    shortcut $K $F "Window Fullscreen" "Make Window Fullscreen" Meta+F
    shortcut $K $F "Window Maximize" "Maximize Window" Meta+Up
    shortcut $K $F "Window Minimize" "Minimize Window" Meta+Down
    shortcut $K $F "Window Quick Tile Top" "Quick Tile Window to the Top"
    shortcut $K $F "Window Quick Tile Bottom" "Quick Tile Window to the Bottom"
    shortcut $K $F "Edit Tiles" "Toggle Tiles Editor"
    shortcut $K $F KrohnkiteToggleFloat "Krohnkite: Toggle Float" Meta+T
    shortcut $K $F KrohnkiteNextLayout "Krohnkite: Next Layout" Meta+Ctrl+L
    shortcut $K $F KrohnkitePreviousLayout "Krohnkite: Previous Layout"
    shortcut $K $F KrohnkiteMonocleLayout "Krohnkite: Select Layout - Monocle"
    shortcut $K $F KrohnkiteTileLayout "Krohnkite: Select Layout - Tile"
    shortcut $K $F KrohnkiteDecrease "Krohnkite: Decrease"
    shortcut $K $F KrohnkiteFocusLeft "Krohnkite: Focus Left" Meta+Alt+H
    shortcut $K $F KrohnkiteFocusDown "Krohnkite: Focus Down" Meta+Alt+J
    shortcut $K $F KrohnkiteFocusUp "Krohnkite: Focus Up" Meta+Alt+K
    shortcut $K $F KrohnkiteFocusRight "Krohnkite: Focus Right" Meta+Alt+L
    shortcut $K $F KrohnkiteShrinkWidth "Krohnkite: Shrink Width" Meta+Ctrl+Left
    shortcut $K $F KrohnkitegrowWidth "Krohnkite: Grow Width" Meta+Ctrl+Right
    shortcut $K $F KrohnkiteShrinkHeight "Krohnkite: Shrink Height" Meta+Ctrl+Up
    shortcut $K $F KrohnkiteGrowHeight "Krohnkite: Grow Height" Meta+Ctrl+Down
    shortcut ksmserver "Session Management" "Lock Session" "Lock Session" Screensaver Meta+L
    shortcut "KDE Keyboard Layout Switcher" "Keyboard Layout Switcher" "Switch to Next Keyboard Layout" "Switch to Next Keyboard Layout"
    shortcut "KDE Keyboard Layout Switcher" "Keyboard Layout Switcher" "Switch to Last-Used Keyboard Layout" "Switch to Last-Used Keyboard Layout"
    shortcut vantablack-wallpaper.desktop "Wallpaper Picker" _launch "Launch Wallpaper Picker" Meta+Ctrl+Space
    if [ -f /usr/share/applications/org.kde.konsole.desktop ]; then
        shortcut org.kde.konsole.desktop Konsole _launch Konsole Meta+Space
    fi
}

step_panel() {
    say "Top bar (Omarchy style)"
    ask "Replace your panels with the Omarchy-style top bar? (desktop icons stay)" || return 0
    local js; js="$(mktemp)"
    {
        printf 'var colorizer = %s;\n' "$(cat "$repo/plasma/panel/colorizer.json")"
        sed "s|@MENU_ICON@|$data/funstorm-vantablack/vantablack-menu.svg|" "$repo/plasma/panel/layout.js"
    } > "$js"
    run qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$js")" >/dev/null
    rm -f "$js"
}

step_wallpaper() {
    say "Wallpaper"
    run mkdir -p "$wallpapers"
    local first; first="$(find "$wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -1)"
    if [ -n "$first" ]; then
        run "$bindir/vantablack-wallpaper-set" "$first"
    else
        warn "no images in $wallpapers yet; put your wallpapers there, then double-click the desktop"
    fi
}

step_login() {
    say "Login screen (SDDM, Omarchy theme with the FunStorm logo)"
    ask "Install SDDM with this theme and make it your login screen? (needs sudo)" || return 0
    run sudo pacman -S --needed sddm
    run sudo rm -rf /usr/share/sddm/themes/funstorm
    run sudo cp -r "$repo/sddm/funstorm" /usr/share/sddm/themes/funstorm
    run sudo install -Dm644 "$repo/sddm/10-funstorm.conf" /etc/sddm.conf.d/10-funstorm.conf
    local dm; dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service)"
    if [ -n "$dm" ] && [ "$dm" != sddm ]; then
        run sudo systemctl disable "$dm.service"
        say "Disabled $dm; to go back: sudo systemctl disable sddm && sudo systemctl enable $dm"
    fi
    run sudo systemctl enable sddm.service
}

step_splash() {
    [ -e /usr/lib/systemd/system/plymouth-quit.service ] || return 0
    say "Boot splash"
    ask "Keep the Plymouth boot animation 3 s longer?" || return 0
    run sudo install -Dm644 "$repo/plymouth/10-longer-splash.conf" \
        /etc/systemd/system/plymouth-quit.service.d/10-longer-splash.conf
    run sudo systemctl daemon-reload
}

# ---------------------------------------------------------------- main
say "FunStorm Vantablack installer${dry:+}$( [ "$dry" -eq 1 ] && echo ' (dry run, nothing changes)')"
backup
for s in $all_steps; do
    want "$s" || continue
    if [ -n "$only" ] || ask "Step: $s?"; then "step_$s"; fi
done
[ "$dry" -eq 1 ] || run qdbus6 org.kde.KWin /KWin reconfigure >/dev/null || true
say "Done. Log out and back in once so every effect and the widgets load fresh."
