#!/usr/bin/env bash
# Arch Linux 2026.11.01 — automated install script for AMD Ryzen 7 4700U laptop
# Run from archiso live environment as root
# Target: 256 GB NVMe, UEFI/GPT, 100 MB EFI, ext4, no LUKS, rEFInd, Hyprland + SDDM

set -euo pipefail

### ── CONFIG ──────────────────────────────────────────────────────────────
DISK="/dev/nvme0n1"               # KIOXIA KBG40ZNV256G
EFI_SIZE="100M"                   # existing EFI partition size
HOSTNAME="archlinux"
USERNAME="user"
TIMEZONE="Europe/Moscow"
LOCALES=("ru_RU.UTF-8" "en_US.UTF-8")
KEYMAP="ru"
XKB_LAYOUT="us,ru"
XKB_OPTIONS="grp:alt_shift_toggle"

# Packages for base system + AMD GPU + WiFi + audio + input + Hyprland deps
BASE_PKGS=(
    base linux linux-firmware linux-headers
    amd-ucode mesa vulkan-radeon libva-mesa-driver mesa-vdpau
    sof-firmware alsa-utils pipewire pipewire-pulse wireplumber
    networkmanager iwd
    rtw88-dkms-git        # Realtek RTL8822CE driver (AUR, built in chroot via paru later)
    bluez bluez-utils
    intel-ucode           # harmless, pulls microcode for any Intel bits
    sudo vim nano git wget curl unzip zip p7zip
    man-db man-pages texinfo
    reflector
)

# Filesystem tools
FS_PKGS=(e2fsprogs dosfstools mtools nvme-cli)

# Bootloader
BOOT_PKGS=(refind efibootmgr)

# Hyprland + Wayland stack (minimal, post-install will add more)
WAYLAND_PKGS=(
    hyprland waybar rofi-wayland sddm
    kitty foot
    polkit-gnome gnome-keyring
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    grim slurp wl-clipboard swaync
    brightnessctl playerctl pamixer
    thunar thunar-volman gvfs gvfs-mtp
    ttf-jetbrains-mono ttf-firacode-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji
)

# User applications
USER_PKGS=(
    chromium vlc git python nodejs npm
    steam
    # AUR packages (will be installed via paru in post-install):
    # spotify onlyoffice-bin opencode-bin happ-proxy
)

ALL_PKGS=("${BASE_PKGS[@]}" "${FS_PKGS[@]}" "${BOOT_PKGS[@]}" "${WAYLAND_PKGS[@]}" "${USER_PKGS[@]}")

### ── HELPERS ─────────────────────────────────────────────────────────────
log() { echo -e "\033[1;32m==>\033[0m $*"; }
err() { echo -e "\033[1;31mERROR:\033[0m $*" >&2; exit 1; }
confirm() { read -rp "$1 [y/N]: " r; [[ $r =~ ^[Yy]$ ]]; }

### ── PRE-CHECKS ──────────────────────────────────────────────────────────
(( EUID == 0 )) || err "Run as root"
[[ -b $DISK ]] || err "Disk $DISK not found"
lsblk -no NAME,SIZE,TYPE "$DISK"
confirm "Target disk is $DISK. ALL DATA WILL BE ERASED. Continue?" || exit 1

### ── NETWORK (for reflector/pacstrap) ────────────────────────────────────
log "Enabling NetworkManager for live env..."
systemctl start NetworkManager || true
# If WiFi needed now: nmcli dev wifi connect "SSID" password "PASS"

### ── MIRRORS ─────────────────────────────────────────────────────────────
log "Updating mirrors for Russia..."
reflector --country Russia --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

### ── PARTITIONING ────────────────────────────────────────────────────────
log "Wiping partition table on $DISK..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"

log "Creating partitions..."
# 1: EFI (use existing 100M if possible, else create)
sgdisk -n 1:0:+${EFI_SIZE} -t 1:ef00 -c 1:"EFI System" "$DISK"
# 2: root (rest of disk)
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux root" "$DISK"

partprobe "$DISK"
sleep 1

EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

### ── FORMATTING ──────────────────────────────────────────────────────────
log "Formatting EFI (FAT32)..."
mkfs.fat -F32 -n "EFI" "$EFI_PART"

log "Formatting root (ext4)..."
mkfs.ext4 -L "ROOT" "$ROOT_PART"

### ── MOUNTING ────────────────────────────────────────────────────────────
log "Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

### ── PACSTRAP ────────────────────────────────────────────────────────────
log "Installing base packages..."
pacstrap -K /mnt "${ALL_PKGS[@]}"

### ── FSTAB ───────────────────────────────────────────────────────────────
log "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

### ── CHROOT CONFIGURATION ────────────────────────────────────────────────
log "Entering chroot for system configuration..."
arch-chroot /mnt /bin/bash <<'CHROOT_EOF'
set -euo pipefail

### Time & Locale
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

cat >/etc/locale.gen <<'LOCALE_EOF'
ru_RU.UTF-8 UTF-8
en_US.UTF-8 UTF-8
LOCALE_EOF
locale-gen

echo 'LANG=ru_RU.UTF-8' >/etc/locale.conf
echo 'KEYMAP=ru' >/etc/vconsole.conf
echo 'FONT=cyr-sun16' >>/etc/vconsole.conf

### Hostname & hosts
echo "archlinux" >/etc/hostname
cat >/etc/hosts <<'HOSTS_EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
HOSTS_EOF

### Initramfs — add amdgpu, i2c_hid_acpi, rtw88 for early load
sed -i 's/^MODULES=()/MODULES=(amdgpu i2c_hid_acpi rtw88_8822ce)/' /etc/mkinitcpio.conf
# Add keyboard, keymap, consolefont hooks for early input
sed -i 's/^HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

### Root password
echo "Set root password:"
passwd

### User
useradd -m -G wheel,video,audio,input,storage,network,power -s /bin/bash user
echo "Set password for user:"
passwd user

### Sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

### NetworkManager
systemctl enable NetworkManager
systemctl enable bluetooth

### SDDM (display manager)
systemctl enable sddm

### rEFInd bootloader
refind-install --usedefault /dev/nvme0n1p1 --alldrivers
# Create minimal refind.conf entry for Arch
cat >>/boot/refind_linux.conf <<'REFIND_EOF'
"Arch Linux"          "root=/dev/nvme0n1p2 rw quiet loglevel=3 amd_pstate=active initrd=/amd-ucode.img initrd=/initramfs-linux.img"
"Arch Linux (fallback)" "root=/dev/nvme0n1p2 rw quiet loglevel=3 amd_pstate=active initrd=/amd-ucode.img initrd=/initramfs-linux-fallback.img"
REFIND_EOF

### Kernel parameters for AMD + WiFi power management fix
mkdir -p /etc/kernel/cmdline.d
cat >/etc/kernel/cmdline.d/amd.conf <<'CMDLINE_EOF'
amd_pstate=active
CMDLINE_EOF
cat >/etc/kernel/cmdline.d/wifi.conf <<'CMDLINE_EOF'
rtw88_8822ce.ips=0 rtw88_8822ce.lps=0 rtw88_8822ce.fw_lps=0
CMDLINE_EOF

### Rebuild initramfs with new cmdline
mkinitcpio -P

### Pacman config: enable multilib (for Steam), color, parallel downloads
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman -Sy

CHROOT_EOF

### ── FINALIZE ────────────────────────────────────────────────────────────
log "Installation complete. Unmounting..."
umount -R /mnt
log "You can now reboot into the new system."
log "After first boot, run post-install.sh as user (not root) to finish Hyprland setup."