#!/bin/bash
#------------------------------------------------------------------------------
# Set Parameters
#------------------------------------------------------------------------------
#Keyboard, Locale, Language, Timezone and Mirror Location settings
keyboard="uk"
locale="en_GB.UTF-8 UTF-8"
language="en_GB.UTF-8"
timezone="Europe/Dublin"
countries='Ireland,United Kingdom,'

#Disk settings - EFIsize is for boot partition. A home partition will be created with the space left after the Root Partition creation
diskname="sda"
efisize="512"
swapsize="4"

#Users Setup
rootpass="5927"
username="djorous"
userpass="5927"

#Package Setup - Default Gnome DE install 
packages="base linux linux-firmware linux-headers util-linux amd-ucode grub efibootmgr os-prober"

#Network Setup
hostname="arch"

#Set Default Editor
editor="nano"

#System settings
swappiness="1"
journalsize="50M"

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
  3 # partion number 4
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
#Create a vfat partition in /dev/disk 1
mkfs.vfat /dev/"${diskname}1"
#Create a swap partition in /dev/disk 2
mkswap /dev/"${diskname}2"
#Create a btrfs partition in /dev/disk 3
mkfs.btrfs -f /dev/"${diskname}3"

#------------------------------------------------------------------------------
# Mount / and create subvolumes
#------------------------------------------------------------------------------
#Mount partitions
mount /dev/"${diskname}3" /mnt
#Create subvolume for /
cd /mnt
btrfs subvolume create @
#Create subvolume for home
btrfs subvolume create @home
#Create subvolume for snapshots
btrfs subvolume create @snapshots
#Create subvolume for var log
btrfs subvolume create @log

#Umount
cd /root
umount /mnt

#Remount / subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/"${diskname}3" /mnt
btrfs quota enable /mnt

#Create mount point directories
mkdir /mnt/{boot,home,.snapshots,var}
mkdir /mnt/var/log

#Mount /home subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/"${diskname}3" /mnt/home
btrfs quota enable /mnt/home

#Mount /snapshots subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/"${diskname}3" /mnt/.snapshots
btrfs quota enable /mnt/.snapshots

#Mount /snapshots log
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@log /dev/"${diskname}3" /mnt/var/log
btrfs quota enable /mnt/var/log

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
pacstrap -C /root/system/files/pacman.conf /mnt $packages

#------------------------------------------------------------------------------
# Move Installer
#------------------------------------------------------------------------------
#Copy Git Automation to new mounted point
cp -r /root/system /mnt/root/system

#------------------------------------------------------------------------------
# Prepare Partition and Chroot Into new partition
#------------------------------------------------------------------------------
#Generate an fstab file (use -U or -L to define by UUID or labels, respectively):
genfstab -U /mnt >> /mnt/etc/fstab