#!/bin/bash
set -euo pipefail

DISK="/dev/sda"
HOSTNAME="archlegacy"
USERNAME=""
USERPASS=""
ROOTPASS=""

echo "⚠️ This will ERASE $DISK and install Arch Linux for LEGACY BIOS boot."
read -rp "Type 'yes' to continue: " confirm
[[ "$confirm" != "yes" ]] && echo "Aborted." && exit 1

# Prompt for credentials
read -rp "Set root password: " -s ROOTPASS; echo
read -rp "Set new username: " USERNAME
read -rp "Set password for $USERNAME: " -s USERPASS; echo

# Partition disk with MBR for BIOS
echo "🧹 Wiping $DISK..."
wipefs -a $DISK
sgdisk --zap-all $DISK || true
parted $DISK --script mklabel msdos
parted $DISK --script mkpart primary ext4 1MiB 100%
parted $DISK --script set 1 boot on

# Format and mount
mkfs.ext4 "${DISK}1"
mount "${DISK}1" /mnt

# Install base system
pacstrap /mnt base base-devel linux linux-firmware sudo networkmanager grub os-prober

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot to setup system
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

echo "root:$ROOTPASS" | chpasswd

useradd -m -G wheel,audio,video,optical,storage $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

# Enable sudo for wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Install Xorg and SDDM
pacman -Sy --noconfirm xorg sddm
systemctl enable sddm
systemctl enable NetworkManager

# Install desktops + apps
pacman -Sy --noconfirm \
  plasma kde-applications \
  gnome gnome-extra \
  xfce4 xfce4-goodies \
  firefox chromium brave \
  steam winetricks lutris \
  kodi retroarch \
  obs-studio vlc gimp \
  neofetch

# Install GRUB for BIOS
grub-install --target=i386-pc --recheck $DISK
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Done
umount -R /mnt
echo "✅ Installation complete! You can now reboot."
