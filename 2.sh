#!/bin/bash
#------------------------------------------------------------------------------
# Clock Setup
#------------------------------------------------------------------------------
#Use timedatectl(1) to ensure the system clock is accurate
timedatectl set-ntp true
#Set the time zone
ln -sf /usr/share/zoneinfo/Europe/Dublin /etc/localtime
#Run hwclock(8) to generate /etc/adjtime
hwclock --systohc

#------------------------------------------------------------------------------
# Setup Location
#------------------------------------------------------------------------------
#Edit /etc/locale.gen and uncomment en_GB.UTF-8 UTF-8 (line 160) and other needed locales
sed -i '160s/.//' /etc/locale.gen
locale-gen
#Create the locale.conf(5) file, and set the LANG variable accordingly
echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "LANGUAGE=en_GB.UTF-8" >> /etc/locale.conf
echo "LC_MESSAGES=en_GB.UTF-8" >> /etc/locale.conf
echo "LC_ALL=en_GB.UTF-8" >> /etc/locale.conf
#Set the console keyboard layout, make the changes persistent in vconsole.conf
echo "KEYMAP=uk" >> /etc/vconsole.conf

#------------------------------------------------------------------------------
# Network Configuration
#------------------------------------------------------------------------------
#Create the hostname file
echo "arch" >> /etc/hostname
#Setup localhost
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts

#------------------------------------------------------------------------------
# Update Export 
#------------------------------------------------------------------------------
#Set default editor to nano
echo "export VISUAL=nano" >> /etc/environment 
echo "export EDITOR=nano" >> /etc/environment

#------------------------------------------------------------------------------
# Configure Bootloader
#------------------------------------------------------------------------------
#Backup Original File
mv /etc/default/grub /etc/default/grub_original
#Change grub file
cp /root/Arch_Automation/Files/grub /etc/default/
#Install booloader and generate configuration
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
#Generate configuration
grub-mkconfig -o /boot/grub/grub.cfg

#------------------------------------------------------------------------------
# Configure Initramfs 
#------------------------------------------------------------------------------
#Backup Original File
mv /etc/mkinitcpio.conf /etc/mkinitcpio.conf_original
#Change mkinitcpio.conf file
cp /root/Arch_Automation/Files/mkinitcpio.conf /etc/

#------------------------------------------------------------------------------
# Configure Pacman
#------------------------------------------------------------------------------
#Backup Original File
mv /etc/pacman.conf /etc/pacman.conf_original
#Change pacman.conf file
cp /root/Arch_Automation/Files/pacman.conf /etc/

#------------------------------------------------------------------------------
# Update Mirrorlist
#------------------------------------------------------------------------------
#Run Reflector
reflector --save /etc/pacman.d/mirrorlist --protocol 'http,https' --country 'Ireland,United Kingdom,' --latest 10 --sort rate --age 12
#Sync Packages
pacman -Syu
#Backup Original File
mv /etc/xdg/reflector/reflector.conf /etc/xdg/reflector/reflector.conf_original
#Copy new version over
cp /root/Arch_Automation/Files/reflector.conf /etc/xdg/reflector/

#------------------------------------------------------------------------------
# Install software
#------------------------------------------------------------------------------
#Networking
yes | pacman -S iptables-nft 
#Software
pacman -S bash-completion bridge-utils cronie dnsmasq firefox firewalld git gnome gnome-tweaks logrotate mlocate nano networkmanager nvidia nvidia-settings openssh qemu-arch-extra pacman-contrib virt-manager

#------------------------------------------------------------------------------
# Disable Wayland
#------------------------------------------------------------------------------
#Disable Wayland
sed -i '5s/.//' /etc/gdm/custom.conf

#------------------------------------------------------------------------------
# Set Swappiness to 1
#------------------------------------------------------------------------------
#Create new file with swappiness configuration
echo "vm.swappiness=1" >> /etc/sysctl.d/10-swappiness.conf

#------------------------------------------------------------------------------
# Set Journal size limit
#------------------------------------------------------------------------------
#Create new file with Journal size limit
mkdir /etc/systemd/journald.conf.d
echo "[Journal]" >> /etc/systemd/journald.conf.d/00-journal-size.conf
echo "SystemMaxUse=50M" >> /etc/systemd/journald.conf.d/00-journal-size.conf

#------------------------------------------------------------------------------
# Blacklist Nvidia USB-C and Watchdog modules
#------------------------------------------------------------------------------
#Blacklist Nvidia USB-C and Watchdog modules
cp /root/Arch_Automation/Files/blacklist.conf /etc/modprobe.d/

#------------------------------------------------------------------------------
# Apply fix for Nvidia Unmount oldroot error 
#------------------------------------------------------------------------------
#Apply fix for Nvidia Unmount oldroot error
cp /root/Arch_Automation/Files/nvidia.shutdown /usr/lib/systemd/system-shutdown/
#Set permissions to file
chmod +x /usr/lib/systemd/system-shutdown/nvidia.shutdown

#------------------------------------------------------------------------------
# Configure/Create Users
#------------------------------------------------------------------------------
#Set the root password
echo root:5927 | chpasswd
#Create non-root user
useradd -m -G wheel djorous
#Set the password
echo djorous:5927 | chpasswd

#------------------------------------------------------------------------------
# Add User to Sudo
#------------------------------------------------------------------------------
#Set user to sudoers
echo "djorous ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/djorous

#------------------------------------------------------------------------------
# Enable Services
#------------------------------------------------------------------------------
#Start services
systemctl enable acpid
systemctl enable bluetooth
systemctl enable cronie
systemctl enable firewalld
systemctl enable fstrim.timer
systemctl enable gdm
systemctl enable libvirtd
systemctl enable logrotate.timer
systemctl enable NetworkManager
systemctl enable paccache.timer
systemctl enable reflector.timer
systemctl enable sshd

#------------------------------------------------------------------------------
# Late Installs to avoid issues
#------------------------------------------------------------------------------
#Install packagekit
pacman -S gnome-software-packagekit-plugin