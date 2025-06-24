#!/bin/bash
set -euo pipefail

# Variables
DISK="/dev/sda"
HOSTNAME="archlinux"
USERNAME=""
USERPASS=""
ROOTPASS=""

echo "This script will erase $DISK completely and install Arch Linux with multiple DEs and apps."
read -rp "Continue? (yes/no): " yn
if [[ "$yn" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

# Prompt user for credentials
read -rp "Set root password: " -s ROOTPASS
echo
read -rp "Set username: " USERNAME
read -rp "Set password for user $USERNAME: " -s USERPASS
echo

# 1. Partition disk (GPT + 2 partitions: EFI and root)
echo "Partitioning disk $DISK..."
sgdisk --zap-all $DISK

# Create partitions: 512M EFI, rest root
sgdisk -n1:0:+512M -t1:ef00 -c1:"EFI System" $DISK
sgdisk -n2:0:0 -t2:8300 -c2:"Linux root" $DISK

partprobe $DISK
sleep 2

EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

# 2. Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 $EFI_PART
mkfs.btrfs -f $ROOT_PART

# 3. Mount root and create btrfs subvolumes
mount $ROOT_PART /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# Mount with subvolumes
mount -o noatime,compress=zstd,subvol=@ $ROOT_PART /mnt
mkdir -p /mnt/home
mount -o noatime,compress=zstd,subvol=@home $ROOT_PART /mnt/home
mkdir -p /mnt/boot/efi
mount $EFI_PART /mnt/boot/efi

# 4. Install base system
echo "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware btrfs-progs sudo networkmanager

# 5. Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 6. Chroot setup
arch-chroot /mnt /bin/bash <<EOF
# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Localization
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname

# Hosts file
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Enable NetworkManager
systemctl enable NetworkManager

# Set root password
echo "root:$ROOTPASS" | chpasswd

# Create user and set password
useradd -m -G wheel,audio,video,optical,storage $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

# Allow wheel group sudo without password (optional, remove if not wanted)
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Install Xorg and display manager
pacman -S --noconfirm xorg sddm

# Enable sddm
systemctl enable sddm

# Install multiple Desktop Environments with apps
pacman -S --noconfirm \
  plasma kde-applications \
  gnome gnome-extra \
  xfce4 xfce4-goodies \
  firefox chromium brave \
  steam winetricks lutris \
  kodi retroarch \
  obs-studio vlc gimp \
  neofetch \
  base-devel

# Clean cache just in case
pacman -Scc --noconfirm

EOF

# 7. Unmount and reboot
umount -R /mnt

echo "Installation complete. Reboot now."
