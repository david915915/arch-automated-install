#!/bin/bash
set -euo pipefail

echo "Updating system..."
sudo pacman -Syu --noconfirm

echo "Enabling multilib repo for Steam..."
sudo sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
sudo pacman -Sy

echo "Installing base apps and browsers..."
sudo pacman -S --noconfirm \
    chromium firefox kodi retroarch libreoffice-fresh gimp steam base-devel git

# Install yay AUR helper (to get google-chrome and others)
if ! command -v yay &>/dev/null; then
  echo "Installing yay AUR helper..."
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay
  makepkg -si --noconfirm
  cd -
  rm -rf /tmp/yay
fi

echo "Installing Google Chrome from AUR..."
yay -S --noconfirm google-chrome

echo "Installing Desktop Environments..."
sudo pacman -S --noconfirm \
    gnome gnome-extra xfce4 xfce4-goodies mate mate-extra

echo "Enabling GDM (GNOME Display Manager) to start on boot..."
sudo systemctl enable gdm

echo "Installation complete! You can reboot now."
