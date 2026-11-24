#!/usr/bin/env bash
# Arch Linux — automated install script for AMD Ryzen 7 4700U laptop
# Run from archiso live environment as root
# Target: NVMe, UEFI/GPT, EFI + ext4 root, no LUKS, rEFInd, Hyprland + SDDM

set -euo pipefail

### ── CONFIG ──────────────────────────────────────────────────────────────
DISK="/dev/nvme0n1"
EFI_SIZE="100M"
HOSTNAME="archlinux"
USERNAME="user"
TIMEZONE="Europe/Moscow"
KEYMAP="ru"

BASE_PKGS=(
    base linux linux-firmware linux-headers
    amd-ucode mesa vulkan-radeon libva-mesa-driver
    sof-firmware alsa-utils pipewire pipewire-pulse wireplumber
    networkmanager iwd
    bluez bluez-utils
    sudo vim nano git wget curl unzip zip p7zip
    man-db man-pages texinfo
    reflector
)

FS_PKGS=(e2fsprogs dosfstools mtools nvme-cli)
BOOT_PKGS=(refind efibootmgr)

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

USER_PKGS=(
    chromium vlc python nodejs npm
    steam
)

ALL_PKGS=(
    "${BASE_PKGS[@]}"
    "${FS_PKGS[@]}"
    "${BOOT_PKGS[@]}"
    "${WAYLAND_PKGS[@]}"
    "${USER_PKGS[@]}"
)

### ── HELPERS ─────────────────────────────────────────────────────────────
log() { echo -e "\033[1;32m==>\033[0m $*"; }
err() { echo -e "\033[1;31mERROR:\033[0m $*" >&2; exit 1; }
confirm() { read -rp "$1 [y/N]: " r; [[ $r =~ ^[Yy]$ ]]; }

### ── PRE-CHECKS ──────────────────────────────────────────────────────────
(( EUID == 0 )) || err "Run as root"
[[ -d /sys/firmware/efi/efivars ]] || err "System not booted in UEFI mode"
[[ -b "$DISK" ]] || err "Disk $DISK not found"

lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$DISK"
confirm "Target disk is $DISK. ALL DATA WILL BE ERASED. Continue?" || exit 1

### ── MIRRORS & MULTILIB FOR PACSTRAP ─────────────────────────────────────
log "Updating mirrors for Russia..."
reflector --country Russia --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true

# Enable [multilib] in live pacman.conf so pacstrap can install steam/32-bit libs
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    cat >>/etc/pacman.conf <<'MULTILIB_LIVE'

[multilib]
Include = /etc/pacman.d/mirrorlist
MULTILIB_LIVE
fi

### ── PARTITIONING ────────────────────────────────────────────────────────
log "Wiping partition table on $DISK..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"

log "Creating partitions..."
sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux root" "$DISK"

partprobe "$DISK"
udevadm settle

if [[ "$DISK" =~ (nvme|mmcblk|loop) ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

### ── FORMATTING & MOUNTING ───────────────────────────────────────────────
log "Formatting EFI (FAT32) and root (ext4)..."
mkfs.fat -F32 -n "EFI" "$EFI_PART"
mkfs.ext4 -F -L "ROOT" "$ROOT_PART"

log "Mounting partitions..."
mountpoint -q /mnt && umount -R /mnt
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

### ── PACSTRAP ────────────────────────────────────────────────────────────
log "Installing packages to /mnt..."
pacstrap -K /mnt "${ALL_PKGS[@]}"

### ── FSTAB ───────────────────────────────────────────────────────────────
log "Generating fstab..."
genfstab -U /mnt > /mnt/etc/fstab

### ── CHROOT CONFIGURATION ────────────────────────────────────────────────
ROOT_PARTUUID="$(blkid -s PARTUUID -o value "$ROOT_PART")"

log "Entering chroot for system configuration..."
arch-chroot /mnt /bin/bash -s -- "$HOSTNAME" "$USERNAME" "$TIMEZONE" "$KEYMAP" "$EFI_PART" "$ROOT_PARTUUID" <<'CHROOT_EOF'
set -euo pipefail

HOSTNAME="$1"
USERNAME="$2"
TIMEZONE="$3"
KEYMAP="$4"
EFI_PART="$5"
ROOT_PARTUUID="$6"

# Time & Locale
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

cat >/etc/locale.gen <<'LOCALE_EOF'
ru_RU.UTF-8 UTF-8
en_US.UTF-8 UTF-8
LOCALE_EOF
locale-gen

echo "LANG=ru_RU.UTF-8" >/etc/locale.conf
{
    echo "KEYMAP=$KEYMAP"
    echo "FONT=cyr-sun16"
} >/etc/vconsole.conf

# Hostname & hosts
echo "$HOSTNAME" >/etc/hostname
cat >/etc/hosts <<HOSTS_EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS_EOF

# Pacman config
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman -Sy

# Kernel cmdline tweaks
mkdir -p /etc/kernel/cmdline.d
echo "amd_pstate=active" >/etc/kernel/cmdline.d/amd.conf
echo "rtw88_8822ce.ips=0 rtw88_8822ce.lps=0 rtw88_8822ce.fw_lps=0" >/etc/kernel/cmdline.d/wifi.conf

# Initramfs modules & rebuild
sed -i 's/^MODULES=()/MODULES=(amdgpu i2c_hid_acpi rtw88_8822ce)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Passwords & user
echo "Set root password:"
passwd

useradd -m -G wheel,video,audio,input,storage,network,power -s /bin/bash "$USERNAME"
echo "Set password for $USERNAME:"
passwd "$USERNAME"

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sddm

# rEFInd bootloader
refind-install --usedefault "$EFI_PART" --alldrivers
cat >/boot/refind_linux.conf <<REFIND_EOF
"Arch Linux"          "root=PARTUUID=${ROOT_PARTUUID} rw quiet loglevel=3 amd_pstate=active rtw88_8822ce.ips=0 rtw88_8822ce.lps=0 rtw88_8822ce.fw_lps=0 initrd=/amd-ucode.img initrd=/initramfs-linux.img"
"Arch Linux (fallback)" "root=PARTUUID=${ROOT_PARTUUID} rw quiet loglevel=3 amd_pstate=active rtw88_8822ce.ips=0 rtw88_8822ce.lps=0 rtw88_8822ce.fw_lps=0 initrd=/amd-ucode.img initrd=/initramfs-linux-fallback.img"
REFIND_EOF
CHROOT_EOF

### ── FINALIZE ────────────────────────────────────────────────────────────
log "Unmounting /mnt..."
umount -R /mnt
log "Done! Reboot now, then run post-install.sh as $USERNAME."
