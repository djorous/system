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
diskname="nvme1n1"
diskpartname="nvme1n1p"
efisize="512"
swapsize="8"

#Users Setup
rootpass="5927"
username="djorous"
userpass="5927"

#Package Setup - Default Gnome DE install 
packages="base linux linux-firmware linux-headers util-linux amd-ucode base-devel pacman-contrib btrfs-progs networkmanager reflector mlocate openssh bash-completion cronie logrotate nano git"

#Network Setup
hostname="battlestation"

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
  +${efisize}MB # boot parttion size
  n # new partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, end at the end
  t # new partition
  1 # partion number 1
  uefi  # default, start immediately after preceding partition
  t # new partition
  p # print the in-memory partition table
  w # write
EOF

#------------------------------------------------------------------------------
# Format Disks
#------------------------------------------------------------------------------
#Create a vfat partition in /dev/disk 1
mkfs.vfat /dev/"${diskpartname}1"
#Create a btrfs partition in /dev/disk 2
mkfs.btrfs -f /dev/"${diskpartname}2"

#------------------------------------------------------------------------------
# Mount / and create subvolumes
#------------------------------------------------------------------------------
#Mount partitions
mount /dev/"${diskpartname}2" /mnt
#Create subvolume for /
cd /mnt

#Create root
btrfs subvolume create @

#Create subvolume for home
btrfs subvolume create @home

#Create subvolume for log
btrfs subvolume create @log

#Create subvolume for pkg
btrfs subvolume create @pkg

#Create subvolume for snapshots
btrfs subvolume create @.snapshots

#Umount
cd /root
umount /mnt

#Remount / subvolume
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/"${diskpartname}2" /mnt

#Create mount point directories
mkdir /mnt/{boot,home,.snapshots,var}
mkdir /mnt/var/log
mkdir /mnt/var/cache
mkdir /mnt/var/cache/pacman
mkdir /mnt/var/cache/pacman/pkg

#Mount subvolumes and partitions
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/"${diskpartname}2" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@log /dev/"${diskpartname}2" /mnt/var/log
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@log /dev/"${diskpartname}2" /mnt/var/cache/pacman/pkg
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@.snapshots /dev/"${diskpartname}2" /mnt/.snapshots
mount /dev/"${diskpartname}1" /mnt/boot

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
# Configure Bootloader
#------------------------------------------------------------------------------
#Chroot into installation
arch-chroot /mnt /bin/bash <<EOF
#Configure systemd-boot
bootctl install
EOF

#------------------------------------------------------------------------------
# Prepare Partition and Chroot Into new partition
#------------------------------------------------------------------------------
#Generate an fstab file (use -U or -L to define by UUID or labels, respectively):
genfstab -U /mnt >> /mnt/etc/fstab

#------------------------------------------------------------------------------
# Create Swapfile
#------------------------------------------------------------------------------
#Create swap file
mkswap -U clear --size "${swapsize}G" --file /mnt/swapfile
#Activate Swap file
swapon /swapfile
#Add entry to Fstab
echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

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
ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
EOF

#------------------------------------------------------------------------------
# Setup Location
#------------------------------------------------------------------------------
#Edit /etc/locale.gen and uncomment en_GB.UTF-8 UTF-8 (line 160) and other needed locales
echo $locale >> /mnt/etc/locale.gen
#Chroot into installation
arch-chroot /mnt /bin/bash <<EOF
locale-gen
EOF

#Create the locale.conf(5) file, and set the LANG variable accordingly
echo "LANG="$language >> /mnt/etc/locale.conf
echo "LANGUAGE="$language >> /mnt/etc/locale.conf
echo "LC_MESSAGES="$language >> /mnt/etc/locale.conf
echo "LC_ALL="$language >> /mnt/etc/locale.conf
#Set the console keyboard layout, make the changes persistent in vconsole.conf
echo "KEYMAP="$keyboard >> /mnt/etc/vconsole.conf

#------------------------------------------------------------------------------
# Network Configuration
#------------------------------------------------------------------------------
#Create the hostname file
echo $hostname >> /mnt/etc/hostname
#Setup localhost
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /mnt/etc/hosts

#------------------------------------------------------------------------------
# Update Export 
#------------------------------------------------------------------------------
#Set default editor to nano
echo "export VISUAL="$editor >> /mnt/etc/environment 
echo "export EDITOR="$editor >> /mnt/etc/environment

#------------------------------------------------------------------------------
# Configure Initramfs 
#------------------------------------------------------------------------------
#Backup Original File
mv /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf_original
#Change mkinitcpio.conf file
cp /root/system/files/mkinitcpio.conf /mnt/etc/
#Run mkinitcpio
arch-chroot /mnt /bin/bash <<EOF
mkinitcpio -P
EOF

#------------------------------------------------------------------------------
# Configure Pacman
#------------------------------------------------------------------------------
#Backup Original File
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf_original
#Change pacman.conf file
cp /root/system/files/pacman.conf /mnt/etc/

#------------------------------------------------------------------------------
# Update Mirrorlist
#------------------------------------------------------------------------------
#Backup Original File
mv /mnt/etc/xdg/reflector/reflector.conf /mnt/etc/xdg/reflector/reflector.conf_original
#Copy new version over
cp /root/system/files/reflector.conf /mnt/etc/xdg/reflector/
#Chroot into installation
arch-chroot /mnt /bin/bash <<EOF
#Run Reflector
reflector
#Sync Packages
pacman -Syu
EOF

#------------------------------------------------------------------------------
# Set Swappiness to 1
#------------------------------------------------------------------------------
#Create new file with swappiness configuration
echo "vm.swappiness="$swappiness >> /mnt/etc/sysctl.d/10-swappiness.conf

#------------------------------------------------------------------------------
# Set Journal size limit
#------------------------------------------------------------------------------
#Create new file with Journal size limit
mkdir /mnt/etc/systemd/journald.conf.d
echo "[Journal]" >> /mnt/etc/systemd/journald.conf.d/00-journal-size.conf
echo "SystemMaxUse="$journalsize >> /mnt/etc/systemd/journald.conf.d/00-journal-size.conf

#------------------------------------------------------------------------------
# Apply fix for Nvidia Unmount oldroot error 
#------------------------------------------------------------------------------
#Apply fix for Nvidia Unmount oldroot error
cp /root/system/files/nvidia.shutdown /mnt/usr/lib/systemd/system-shutdown/
#Set permissions to file
chmod +x /mnt/usr/lib/systemd/system-shutdown/nvidia.shutdown

#------------------------------------------------------------------------------
# Configure/Create Users
#------------------------------------------------------------------------------
#Chroot into installation
arch-chroot /mnt /bin/bash <<EOF
#Set the root password
echo root:$rootpass | chpasswd

#Create non-root user
useradd -m -G wheel $username
#Set the password
echo $username":"$userpass | chpasswd
EOF

#------------------------------------------------------------------------------
# Add User to Sudo
#------------------------------------------------------------------------------
#Set user to sudoers
echo $username" ALL=(ALL) NOPASSWD: ALL" >> /mnt/etc/sudoers.d/$username

#------------------------------------------------------------------------------
# Enable Services
#------------------------------------------------------------------------------
#Chroot into installation
arch-chroot /mnt /bin/bash <<EOF
#Start services
systemctl enable cronie
systemctl enable fstrim.timer
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
sudo -i -u $username
#Set home directory
cd /home/$username
#Clone rep
git clone https://aur.archlinux.org/paru-bin.git
#Enter local repository copy
cd /home/$username/paru-bin
#Start build
makepkg --syncdeps --install --needed --noconfirm
#Install AUR packages
paru -Sua
EOF

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------
#Cleanup install folder
rm -rf /mnt/home/${username}/paru-bin

#------------------------------------------------------------------------------
#Syncronize Locate
#------------------------------------------------------------------------------
#Syncronize db
arch-chroot /mnt /bin/bash <<EOF
updatedb
EOF

#------------------------------------------------------------------------------
#Reboot
#------------------------------------------------------------------------------
#Restart system
#systemctl reboot
