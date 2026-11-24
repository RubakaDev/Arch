#!/usr/bin/env bash
# Post-install configuration for Hyprland + SDDM + user apps
# Run as USER (not root) after first boot into installed system

set -euo pipefail

### ── CONFIG ──────────────────────────────────────────────────────────────
USERNAME="user"
DOTFILES_REPO=""  # set if you have one later

AUR_PKGS=(
    spotify
    onlyoffice-bin
    opencode-bin
    happ-proxy
    rtw88-dkms-git   # WiFi driver for RTL8822CE
)

FLATPAK_PKGS=()     # optional, add if needed

### ── HELPERS ─────────────────────────────────────────────────────────────
log() { echo -e "\033[1;32m==>\033[0m $*"; }
err() { echo -e "\033[1;31mERROR:\033[0m $*" >&2; exit 1; }

(( EUID != 0 )) || err "Run as user, not root"

### ── PARU (AUR helper) ───────────────────────────────────────────────────
if ! command -v paru &>/dev/null; then
    log "Installing paru..."
    sudo pacman -S --needed --noconfirm base-devel git
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$tmpdir"
    cd "$tmpdir"
    makepkg -si --noconfirm
    cd -
    rm -rf "$tmpdir"
else
    log "paru already installed"
fi

### ── AUR PACKAGES ────────────────────────────────────────────────────────
log "Installing AUR packages..."
paru -S --needed --noconfirm "${AUR_PKGS[@]}"

### ── FLATPAK (optional) ──────────────────────────────────────────────────
if [[ ${#FLATPAK_PKGS[@]} -gt 0 ]]; then
    log "Installing Flatpaks..."
    flatpak install -y flathub "${FLATPAK_PKGS[@]}"
fi

### ── HYPRLAND CONFIG ─────────────────────────────────────────────────────
log "Setting up Hyprland config..."
mkdir -p ~/.config/hypr ~/.config/waybar ~/.config/rofi ~/.config/kitty ~/.config/swaync

# hyprland.conf — minimal but functional
cat >~/.config/hypr/hyprland.conf <<'HYPR_EOF'
# Minimal Hyprland config for AMD Ryzen 7 4700U / Vega iGPU
# See: https://wiki.hyprland.org/Configuring/Configuring-Hyprland/

monitor=,preferred,auto,1

input {
    kb_layout = us,ru
    kb_options = grp:alt_shift_toggle
    kb_variant =
    kb_model =
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = false
        disable_while_typing = true
    }
    sensitivity = 0
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faee) rgba(74c7ecee) 45deg
    col.inactive_border = rgba(313244ee)
    layout = dwindle
    allow_tearing = false
}

decoration {
    rounding = 8
    blur {
        enabled = true
        size = 3
        passes = 1
        new_optimizations = true
    }
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1e1e2eee)
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

gestures {
    workspace_swipe = true
}

# Autostart
exec-once = waybar &
exec-once = swaync &
exec-once = nm-applet --indicator &
exec-once = blueman-applet &

# Environment variables for Wayland / Qt / GTK
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = MOZ_ENABLE_WAYLAND,1
env = NVD_BACKEND,wayland

# Keybindings
$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating
bind = $mainMod, R, exec, rofi -show drun
bind = $mainMod, P, pseudo
bind = $mainMod, J, togglesplit
bind = $mainMod, F, fullscreen
bind = $mainMod, L, exec, swaylock -f -c 1e1e2e
bind = $mainMod, S, exec, grim -g "$(slurp)" - | wl-copy
bind = $mainMod, W, exec, chromium
bind = $mainMod, T, exec, foot

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Move windows
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, down, movewindow, d

# Resize
bind = $mainMod CTRL, left, resizeactive, -20 0
bind = $mainMod CTRL, right, resizeactive, 20 0
bind = $mainMod CTRL, up, resizeactive, 0 -20
bind = $mainMod CTRL, down, resizeactive, 0 20

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Volume / brightness
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = , XF86MonBrightnessUp, exec, brightnessctl set 5%+
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Laptop lid
bind = , XF86Sleep, exec, systemctl suspend

# Window rules
windowrulev2 = float, class:^(pavucontrol)$
windowrulev2 = float, class:^(blueman-manager)$
windowrulev2 = float, class:^(nm-connection-editor)$
windowrulev2 = float, title:^(Picture-in-Picture)$
HYPR_EOF

### ── WAYBAR CONFIG ───────────────────────────────────────────────────────
log "Setting up Waybar config..."
cat >~/.config/waybar/config.jsonc <<'WAYBAR_EOF'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "bluetooth", "battery", "tray"],
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
            "6": "6", "7": "7", "8": "8", "9": "9", "10": "10",
            "active": "{icon}",
            "inactive": "{icon}",
            "urgent": "{icon}"
        }
    },
    "hyprland/window": {
        "format": "{}",
        "max-length": 50
    },
    "clock": {
        "format": "{}",
        "format-alt": "%Y-%m-%d %H:%M:%S",
        "tooltip-format": "<big>{:%Y-%m-%d}</big>\n<big>{:%H:%M:%S}</big>",
        "interval": 1
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-bluetooth": "{icon} {volume}% 🎧",
        "format-muted": "🔇 Muted",
        "format-source": "🎤 {volume}%",
        "format-source-muted": "🔇 Mic Muted",
        "on-click": "pavucontrol"
    },
    "network": {
        "format-wifi": " {essid} ({signalStrength}%)",
        "format-ethernet": " Connected",
        "format-disconnected": "❌ Disconnected",
        "tooltip-format": "{ifname}: {ipaddr}",
        "on-click": "nm-connection-editor"
    },
    "bluetooth": {
        "format": "{icon} {device_name}",
        "format-disconnected": " Off",
        "format-connected": " {device_name}",
        "on-click": "blueman-manager"
    },
    "battery": {
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-alt": "{icon} {time}",
        "threshold": 15,
        "tooltip-format": "{capacity}% {time}"
    },
    "tray": {
        "icon-size": 18,
        "spacing": 6
    }
}
WAYBAR_EOF

cat >~/.config/waybar/style.css <<'WAYBAR_CSS_EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono Nerd Font", "FiraCode Nerd Font", monospace;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
    transition-property: background-color;
    transition-duration: .5s;
}

#workspaces button {
    padding: 0 8px;
    color: #6c7086;
    transition: all 0.2s;
}

#workspaces button.active {
    color: #89b4fa;
    background: rgba(137, 180, 250, 0.1);
    border-radius: 4px;
}

#workspaces button.urgent {
    color: #f38ba8;
}

#window {
    padding: 0 12px;
    color: #cdd6f4;
}

#clock {
    padding: 0 12px;
    color: #fab387;
    font-weight: bold;
}

#pulseaudio, #network, #bluetooth, #battery {
    padding: 0 12px;
    color: #a6e3a1;
}

#tray {
    padding: 0 8px;
}

#battery.critical:not(.charging) {
    color: #f38ba8;
    animation: blink 1s linear infinite;
}

@keyframes blink {
    to { color: #1e1e2e; }
}
WAYBAR_CSS_EOF

### ── ROFI CONFIG ─────────────────────────────────────────────────────────
log "Setting up Rofi config..."
cat >~/.config/rofi/config.rasi <<'ROFI_EOF'
configuration {
    modi: "drun,window,run";
    show-icons: true;
    icon-theme: "Adwaita";
    font: "JetBrains Mono Nerd Font 12";
    theme: "~/.config/rofi/theme.rasi";
}

@theme "~/.config/rofi/theme.rasi"
ROFI_EOF

cat >~/.config/rofi/theme.rasi <<'ROFI_THEME_EOF'
* {
    background: #1e1e2e;
    background-alt: #313244;
    foreground: #cdd6f4;
    selected: #89b4fa;
    urgent: #f38ba8;
    border: #45475a;
}

window {
    width: 600px;
    location: center;
    anchor: center;
    fullscreen: false;
    border: 2px;
    border-radius: 12px;
    padding: 12px;
}

inputbar {
    children: [prompt, entry];
    spacing: 8px;
    padding: 8px;
    background: #181825;
    border-radius: 8px;
}

prompt {
    enabled: true;
    background: #89b4fa;
    color: #1e1e2e;
    padding: 4px 12px;
    border-radius: 6px;
    font-weight: bold;
}

entry {
    placeholder: "Search apps...";
    placeholder-color: #6c7086;
    background: transparent;
    text-color: #cdd6f4;
    padding: 4px 8px;
}

listview {
    columns: 1;
    lines: 10;
    spacing: 4px;
    padding: 8px;
}

element {
    padding: 8px 12px;
    border-radius: 6px;
    text-color: #cdd6f4;
}

element selected {
    background: #313244;
    text-color: #89b4fa;
}

element-text {
    horizontal-align: 0.5;
}

element-icon {
    size: 24px;
    vertical-align: 0.5;
}
ROFI_THEME_EOF

### ── KITTY CONFIG ────────────────────────────────────────────────────────
log "Setting up Kitty config..."
cat >~/.config/kitty/kitty.conf <<'KITTY_EOF'
font_family JetBrains Mono Nerd Font
bold_font auto
italic_font auto
bold_italic_font auto
font_size 11.0
adjust_line_height 0%
adjust_column_width 0%

background #1e1e2e
foreground #cdd6f4
selection_background #45475a
selection_foreground #cdd6f4

cursor #f5e0dc
cursor_text_color #1e1e2e

url_color #89b4fa

color0 #1e1e2e
color1 #f38ba8
color2 #a6e3a1
color3 #f9e2af
color4 #89b4fa
color5 #f5c2e7
color6 #94e2d5
color7 #bac2de
color8 #585b70
color9 #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #f5c2e7
color14 #94e2d5
color15 #a6adc8

shell_integration no-rc
enable_audio_bell no
visual_bell_duration 0.1
window_padding_width 8
window_margin_width 0
hide_window_decorations no
window_border_width 2
window_border_color #45475a
active_border_color #89b4fa
inactive_border_color #45475a
tab_bar_style fade
tab_bar_min_tabs 2
tab_bar_edge bottom
tab_powerline_style slanted
active_tab_background #89b4fa
active_tab_foreground #1e1e2e
inactive_tab_background #313244
inactive_tab_foreground #cdd6f4
tab_bar_background #1e1e2e
EOF

### ── SWAYNC (notifications) ──────────────────────────────────────────────
log "Setting up SwayNC config..."
cat >~/.config/swaync/config.json <<'SWAYNC_EOF'
{
    "positionX": "right",
    "positionY": "top",
    "layer": "overlay",
    "control-center-layer": "overlay",
    "control-center-width": 400,
    "control-center-height": 600,
    "cssPriority": "application",
    "notification-body": {
        "text": "{body}",
        "markup": true
    },
    "notification-icon-size": 48,
    "notification-window-width": 350,
    "timeout": 5,
    "timeout-low": 3,
    "timeout-critical": 0,
    "fit-to-screen": true,
    "keyboard-shortcuts": true,
    "image-visibility": "when-available",
    "transition-time": 200,
    "hide-on-clear": true,
    "hide-on-action": true,
    "script-fail-notify": true,
    "widgets": ["title", "dnd", "notifications"],
    "widget-config": {
        "title": {
            "text": "Notifications",
            "clear-all-button": true,
            "button-text": "Clear All"
        },
        "dnd": {
            "text": "Do Not Disturb",
            "on-icon": "󰂛",
            "off-icon": "󰂚"
        }
    }
}
SWAYNC_EOF

cat >~/.config/swaync/style.css <<'SWAYNC_CSS_EOF'
* {
    font-family: "JetBrains Mono Nerd Font", "FiraCode Nerd Font", monospace;
    font-size: 13px;
}

#notification-window {
    background: #1e1e2e;
    border: 2px solid #45475a;
    border-radius: 12px;
    padding: 12px;
}

#notification {
    background: #313244;
    border-radius: 8px;
    padding: 12px;
    margin: 4px 0;
}

#notification.critical {
    border-left: 4px solid #f38ba8;
}

#notification-body {
    color: #cdd6f4;
}

#notification-title {
    font-weight: bold;
    color: #89b4fa;
}

#control-center {
    background: #1e1e2e;
    border: 2px solid #45475a;
    border-radius: 12px;
}

#widget-title {
    color: #89b4fa;
    font-weight: bold;
    padding: 12px;
}

#widget-dnd {
    padding: 12px;
    color: #cdd6f4;
}

#widget-dnd:checked {
    color: #f38ba8;
}
SWAYNC_CSS_EOF

### ── ENVIRONMENT VARIABLES (systemd user) ───────────────────────────────
log "Setting up environment variables..."
mkdir -p ~/.config/environment.d
cat >~/.config/environment.d/90-wayland.conf <<'ENV_EOF'
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=Hyprland
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
GDK_BACKEND=wayland,x11
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
MOZ_ENABLE_WAYLAND=1
NVD_BACKEND=wayland
EDITOR=nvim
VISUAL=nvim
BROWSER=chromium
TERMINAL=kitty
ENV_EOF

### ── USER SERVICES ───────────────────────────────────────────────────────
log "Enabling user services..."
systemctl --user enable pipewire pipewire-pulse wireplumber
systemctl --user start pipewire pipewire-pulse wireplumber

### ── GNOME KEYRING (for SDDM auto-login unlock) ──────────────────────────
log "Configuring GNOME Keyring for SDDM..."
# Add to ~/.config/hypr/hyprland.conf already handled via exec-once

### ── ADDITIONAL TOOLS CONFIG ─────────────────────────────────────────────
# Git config
git config --global user.name "Your Name" 2>/dev/null || true
git config --global user.email "you@example.com" 2>/dev/null || true
git config --global init.defaultBranch main
git config --global pull.rebase false

# npm global dir (avoid sudo)
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc

### ── AMD GPU POWER MANAGEMENT ────────────────────────────────────────────
log "Setting up AMD GPU power profile..."
sudo mkdir -p /etc/systemd/system/
cat | sudo tee /etc/systemd/system/amd-pstate.service >/dev/null <<'AMD_EOF'
[Unit]
Description=Set AMD PState to active
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo active > /sys/devices/system/cpu/amd_pstate/status'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
AMD_EOF
sudo systemctl enable amd-pstate.service

# TLP for laptop power management
sudo pacman -S --needed --noconfirm tlp tlp-rdw
sudo systemctl enable tlp
sudo tlp start

### ── WI-FI POWER MANAGEMENT FIX (RTL8822CE) ──────────────────────────────
log "Applying permanent WiFi power management fix..."
sudo mkdir -p /etc/NetworkManager/conf.d
cat | sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf >/dev/null <<'WIFI_EOF'
[connection]
wifi.powersave = 2
WIFI_EOF

# Modprobe options already in kernel cmdline from install.sh

### ── CLEANUP ─────────────────────────────────────────────────────────────
log "Cleaning up..."
paru -Sc --noconfirm
sudo pacman -Sc --noconfirm
sudo journalctl --vacuum-time=2weeks

log "Post-install complete!"
log "Reboot and select Hyprland from SDDM."
log "Keybinds: SUPER+Return = terminal, SUPER+R = rofi, SUPER+E = thunar"
log "Config files in ~/.config/hypr/, ~/.config/waybar/, ~/.config/rofi/, ~/.config/kitty/"