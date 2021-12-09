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
#Move Git Automation to new mounted point
cp -r /root/Arch_Automation /mnt/root/Arch_Automation

#------------------------------------------------------------------------------
# Prepare Partition and Chroot Into new partition
#------------------------------------------------------------------------------
#Generate an fstab file (use -U or -L to define by UUID or labels, respectively):
genfstab -U /mnt >> /mnt/etc/fstab

#Change root into the new system:
arch-chroot /mnt /bin/bash