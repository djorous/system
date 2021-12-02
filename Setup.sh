#!/bin/bash

#------------------------------------------------------------------------------
# Disk Partitioning
#------------------------------------------------------------------------------
#Clean Disk Partition
#sgdisk --zap-all /dev/nvme0n1
#Create Boot Partition
#echo "n\n1\n\n+512M\nef00\nw\ny\n" | gdisk /dev/nvme0n1
#Create Create Swap Partition
#echo "n\n2\n\n+4G\n8200\nw\ny\n" | gdisk /dev/nvme0n1
#Create Create / Partition
#echo "n\n3\n\n+20G\n8e00\nw\ny\n" | gdisk /dev/nvme0n1
#Create Create /home Partition
#echo "n\n4\n\n\n8e00\nw\ny\n" | gdisk /dev/nvme0n1

#------------------------------------------------------------------------------
# Format Disks
#------------------------------------------------------------------------------
#Create a vfat partition in /dev/nvme0n1p1
mkfs.vfat /dev/sda1
#Create a swap partition in /dev/sda1
mkswap /dev/sda2
#Create a btrfs partition in /dev/sda1
mkfs.btrfs -f /dev/sda3
#Create a btrfs partition in /dev/sda1
mkfs.btrfs -f /dev/sda4

#------------------------------------------------------------------------------
# Create Swap
#------------------------------------------------------------------------------
#Mount swap partition
swapon /dev/sda2

#------------------------------------------------------------------------------
# Mount / and create subvolumes
#------------------------------------------------------------------------------
#Create subvolume for /
mount /dev/sda3 /mnt
cd /mnt
btrfs subvolume create @
cd /root
umount /mnt

#Create subvolume for /home
mount /dev/sda4 /mnt
cd /mnt
btrfs subvolume create @home
cd /root
umount /mnt

#Remount / subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/sda3 /mnt

#Create mount point directories
mkdir /mnt/{boot,home}

#Mount /home subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/sda4 /mnt/home

#Mount boot partition
mount /dev/sda1 /mnt/boot

#------------------------------------------------------------------------------
# Install Packages
#------------------------------------------------------------------------------
#Use the pacstrap(8) script to install the base package, Linux kernel and firmware for common hardware
pacstrap /mnt base btrfs-progs linux linux-firmware amd-ucode git nano reflector grub efibootmgr networkmanager acpi acpi_call acpid base-devel bash-completion openssh os-prober util-linux cronie ntfs-3g mlocate logrotate pacman-contrib

#------------------------------------------------------------------------------
# Move Installer
#------------------------------------------------------------------------------
#Move Git Automation to new mounted point
cp -r /root/Arch_Automation /mnt/root/Arch_Automation

#------------------------------------------------------------------------------
# Prepare Partition and Chroot Into new partition
#------------------------------------------------------------------------------
#Generate an fstab file (use -U or -L to define by UUID or labels, respectively):
genfstab -U /mnt >> /mnt/etc/fstab

#Change root into the new system:
arch-chroot /mnt /bin/bash <<EOF

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
pacman -S --noconfirm nvidia nvidia-utils nvidia-settings gnome gnome-tweaks gnome-software-packagekit-plugin 
#Remove unwanted default packages
pacman -Rns --noconfirm cheese epiphany gnome-books gnome-boxes gnome-calendar gnome-characters gnome-contacts gnome-font-viewer gnome-music simple-scan
#remove unwanted icons
cd /usr/share/applications
rm avahi-discover.desktop bssh.desktop bvnc.desktop cmake-gui.desktop lstopo.desktop qv4l2.desktop qvidcap.desktop

#------------------------------------------------------------------------------
#Syncronize Locate
#------------------------------------------------------------------------------
#Syncronize db
updatedb

#------------------------------------------------------------------------------
# Enable Services
#------------------------------------------------------------------------------
#Start services"
systemctl enable acpid
systemctl enable bluetooth
systemctl enable cronie
systemctl enable fstrim.timer
systemctl enable gdm
systemctl enable logrotate.timer
systemctl enable NetworkManager
systemctl enable paccache.timer
systemctl enable reflector.timer
systemctl enable sshd
EOF

#------------------------------------------------------------------------------
# Setup Paru + AUR
#------------------------------------------------------------------------------
#Change root into the new system:
arch-chroot /mnt /bin/bash <<EOF
#Change user
sudo -i -u djorous
#Set home directory
cd /home/djorous
#Clone rep
git clone https://aur.archlinux.org/paru-bin.git
#Enter local repository copy
cd /home/djorous/paru-bin
#Start build
makepkg --syncdeps --install --needed --noconfirm
#Install Chrome
paru -S --noconfirm google-chrome chrome-gnome-shell timeshift timeshift-autosnap
#Close
EOF
