#!/bin/bash
#------------------------------------------------------------------------------
# Set Parameters
#------------------------------------------------------------------------------
#Keyboard layout
keyboard=uk
#Name from /dev
diskname=sda
#Size in MB
efisize=512
#Size in GB
swapsize=4
#Size in GB
rootsize=40
#Reflector countries
countries='Ireland,United Kingdom,'
#Timezone
timezone=Europe/Dublin 

#------------------------------------------------------------------------------
# Set Keyboard
#------------------------------------------------------------------------------
#Load configuration for keyboard region
loadkeys=$keyboard

#------------------------------------------------------------------------------
# Clear disk
#------------------------------------------------------------------------------
#zap disk
sgdisk --zap-all /dev/$diskname

#------------------------------------------------------------------------------
# Disk Partitioning
#------------------------------------------------------------------------------
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/$diskname
  g # clear the in memory partition table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
  +${efisize}M # boot parttion size
  n # new partition
  2 # partion number 2
    # default, start immediately after preceding partition
  +${swapsize}G # swap partition
  n # new partition
  3 # partion number 3
    # default, start immediately after preceding partition
  +${rootsize}G  # / partition
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
mkfs.vfat /dev/"${diskname}1"
#Create a swap partition in /dev/sda2
mkswap /dev/"${diskname}2"
#Create a btrfs partition in /dev/sda3
mkfs.btrfs -f /dev/"${diskname}3"
#Create a btrfs partition in /dev/sda4
mkfs.btrfs -f /dev/"${diskname}4"

#------------------------------------------------------------------------------
# Mount / and create subvolumes
#------------------------------------------------------------------------------
#Mount partitions
mount /dev/"${diskname}3" /mnt
#Create subvolume for /
cd /mnt
btrfs subvolume create @
#Umount
cd /root
umount /mnt

#Mount partitions
mount /dev/"${diskname}4" /mnt
#Create subvolume for /home
cd /mnt
btrfs subvolume create @home
#Umount
cd /root
umount /mnt

#Remount / subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/"${diskname}3" /mnt
btrfs quota enable /mnt

#Create mount point directories
mkdir /mnt/{boot,home}

#Mount /home subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/"${diskname}4" /mnt/home
btrfs quota enable /mnt/home

#Mount boot partition
mount /dev/"${diskname}1" /mnt/boot

#Mount swap partition
swapon /dev/"${diskname}2"

#------------------------------------------------------------------------------
# Update Mirrorlist
#------------------------------------------------------------------------------
#Run reflector
reflector --save /etc/pacman.d/mirrorlist --protocol 'http,https' --country "$countries" --latest 10 --sort rate --age 12

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
#Chroot into installation
arch-chroot /mnt /bin/bash <<EOF
#Use timedatectl(1) to ensure the system clock is accurate
timedatectl set-ntp true
#Run hwclock(8) to generate /etc/adjtime
hwclock --systohc
#Set the time zone
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
EOF
