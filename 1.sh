#!/bin/bash
#------------------------------------------------------------------------------
# Clear disk
#------------------------------------------------------------------------------
#zap disk
sgdisk --zap-all /dev/sda

#------------------------------------------------------------------------------
# Disk Partitioning
#------------------------------------------------------------------------------
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
  g # clear the in memory partition table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
  +512M # 100 MB boot parttion
  n # new partition
  2 # partion number 2
    # default, start immediately after preceding partition
  +4G # swap partition
  n # new partition
  3 # partion number 3
    # default, start immediately after preceding partition
  +40G # / partition
  n # new partition
  4 # partion number 4
    # default, start immediately after preceding partition
    # default, end at the end
  t # new partition
  1 # partion number 1
  uefi  # default, start immediately after preceding partition
  t # new partition
  2 # partion number 2
  swap  # default, start immediately after preceding partition  
  p # print the in-memory partition table
  w # write
EOF

#------------------------------------------------------------------------------
# Format Disks
#------------------------------------------------------------------------------
#Create a vfat partition in /dev/sda
mkfs.vfat /dev/sda1
#Create a swap partition in /dev/sda2
mkswap /dev/sda2
#Create a btrfs partition in /dev/sda3
mkfs.btrfs -f /dev/sda3
#Create a btrfs partition in /dev/sda4
mkfs.btrfs -f /dev/sda4

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
btrfs quota enable /mnt

#Create mount point directories
mkdir /mnt/{boot,home}

#Mount /home subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/sda4 /mnt/home
btrfs quota enable /mnt/home

#Mount boot partition
mount /dev/sda1 /mnt/boot

#Mount swap partition
swapon /dev/sda2

#------------------------------------------------------------------------------
# Update Mirrorlist
#------------------------------------------------------------------------------
#Run reflector
reflector --save /etc/pacman.d/mirrorlist --protocol 'http,https' --country 'Ireland,United Kingdom,' --latest 10 --sort rate --age 12

#------------------------------------------------------------------------------
# Install Packages
#------------------------------------------------------------------------------
#Use the pacstrap(8) script to install the base package, Linux kernel and firmware for common hardware
pacstrap -C /root/Arch_Automation/Files/pacman.conf /mnt base linux linux-firmware linux-headers util-linux grub efibootmgr os-prober amd-ucode acpi acpi_call acpid btrfs-progs base-devel ntfs-3g reflector bash-completion bridge-utils cronie dnsmasq firefox firewalld git gnome gnome-tweaks iptables-nft logrotate mlocate nano networkmanager nvidia nvidia-settings openssh qemu-arch-extra pacman-contrib virt-manager

#------------------------------------------------------------------------------
# Move Installer
#------------------------------------------------------------------------------
#Copy Git Automation to new mounted point
cp -r /root/Arch_Automation /mnt/root/Arch_Automation

#------------------------------------------------------------------------------
# Prepare Partition and Chroot Into new partition
#------------------------------------------------------------------------------
#Generate an fstab file (use -U or -L to define by UUID or labels, respectively):
genfstab -U /mnt >> /mnt/etc/fstab

#------------------------------------------------------------------------------
# Clock Setup
#------------------------------------------------------------------------------
#Use timedatectl(1) to ensure the system clock is accurate
timedatectl set-ntp true
#Run hwclock(8) to generate /etc/adjtime
hwclock --systohc
#Set the time zone
ln -sf /usr/share/zoneinfo/Europe/Dublin /etc/localtime

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
#Run mkinitcpio
mkinitcpio -P

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