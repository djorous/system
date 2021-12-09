#!/bin/bash
#------------------------------------------------------------------------------
# Initial Configuration
#------------------------------------------------------------------------------
#Use timedatectl(1) to ensure the system clock is accurate
timedatectl set-ntp true

#Set the time zone
ln -sf /usr/share/zoneinfo/Europe/Dublin /etc/localtime

#Run hwclock(8) to generate /etc/adjtime
hwclock --systohc

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

#Create the hostname file
echo "arch" >> /etc/hostname

#Setup localhost
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts

#Set default editor to nano
echo "export VISUAL=nano" >> /etc/environment 
echo "export EDITOR=nano" >> /etc/environment

#------------------------------------------------------------------------------
# Configure Bootloader
#------------------------------------------------------------------------------
#Networking
pacman -S bridge-utils dnsmasq firewalld iptables-nft networkmanager
#Software
pacman -S bash-completion cronie git nano nvidia nvidia-utils nvidia-settings logrotate mlocate openssh pacman-contrib reflector

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
# Setup DE
#------------------------------------------------------------------------------
#Install Software
pacman -S gnome gnome-tweaks firefox
#Disable Wayland
sed -i '5s/.//' /etc/gdm/custom.conf

#------------------------------------------------------------------------------
# Setup DE
#------------------------------------------------------------------------------
#Install software VM 
pacman -S virt-manager qemu qemu-arch-extra edk2-ovmf vde2

#------------------------------------------------------------------------------
# Install system fonts
#------------------------------------------------------------------------------
#Install group of fonts for general purpose 
pacman -S dina-font tamsyn-font bdf-unifont ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation ttf-linux-libertine noto-fonts ttf-roboto tex-gyre-fonts tf-ubuntu-font-family ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-inconsolata ttf-jetbrains-mono ttf-monofur adobe-source-code-pro-fonts cantarell-fonts inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji

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
EOF
#------------------------------------------------------------------------------
# Late Installs to avoid issues
#------------------------------------------------------------------------------
#Install packagekit
pacman -S gnome-software-packagekit-plugin