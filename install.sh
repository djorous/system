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
packages="base linux linux-firmware linux-headers util-linux amd-ucode grub efibootmgr os-prober acpi acpi_call acpid btrfs-progs base-devel networkmanager ntfs-3g reflector nvidia bash-completion cronie git mlocate logrotate nano openssh pacman-contrib rsync bridge-utils dnsmasq edk2-ovmf firewalld iptables-nft qemu virt-manager eog evince file-roller gdm gnome-backgrounds gnome-calculator gnome-calendar gnome-clocks gnome-color-manager gnome-control-center gnome-disk-utility gnome-keyring gnome-logs gnome-menus gnome-photos gnome-screenshot gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-system-monitor gnome-terminal gnome-user-share gnome-weather gvfs gvfs-afc gvfs-goa gvfs-google gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb mutter nautilus sushi xdg-user-dirs-gtk yelp gnome-tweaks gnome-themes-extra papirus-icon-theme firefox code snapper snap-pac"

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

#Create mount point directories
mkdir /mnt/{boot,home,.snapshots,var}
mkdir /mnt/var/log

#Mount subvolumes and partitions
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/"${diskname}3" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/"${diskname}3" /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@log /dev/"${diskname}3" /mnt/var/log
mount /dev/"${diskname}1" /mnt/boot
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
# Configure Bootloader
#------------------------------------------------------------------------------
#Backup Original File
mv /mnt/etc/default/grub /mnt/etc/default/grub_original
#Change grub file
cp /root/system/files/grub /mnt/etc/default/

#Chroot into installation
arch-chroot /mnt /bin/bash <<EOF
#Install booloader and generate configuration
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
#Generate configuration
grub-mkconfig -o /boot/grub/grub.cfg
EOF

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
reflector --save /etc/pacman.d/mirrorlist --protocol 'http,https' --country 'Ireland,United Kingdom,' --latest 10 --sort rate --age 12
#Sync Packages
pacman -Syu
EOF

#------------------------------------------------------------------------------
# Disable Wayland
#------------------------------------------------------------------------------
#Disable Wayland
sed -i '5s/.//' /mnt/etc/gdm/custom.conf

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
# Blacklist Nvidia USB-C and Watchdog modules
#------------------------------------------------------------------------------
#Blacklist Nvidia USB-C and Watchdog modules
cp /root/system/files/blacklist.conf /mnt/etc/modprobe.d/

#------------------------------------------------------------------------------
# Apply fix for Nvidia Unmount oldroot error 
#------------------------------------------------------------------------------
#Apply fix for Nvidia Unmount oldroot error
cp /root/system/files/nvidia.shutdown /mnt/usr/lib/systemd/system-shutdown/
#Set permissions to file
chmod +x /mnt/usr/lib/systemd/system-shutdown/nvidia.shutdown

#------------------------------------------------------------------------------
# Configure Snapper
#------------------------------------------------------------------------------
#Adjust permissions
chmod 750 /mnt/.snapshots
chmod a+rx /mnt/.snapshots
chown :wheel /mnt/.snapshots

#Move configuration file 
cp /root/system/files/default /mnt/etc/snapper/configs/default

#Create pacman hook
mkdir /mnt/etc/pacman.d/hooks
cp /root/system/files/50-bootbackup.hook /mnt/etc/pacman.d/hooks/

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
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
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
#Install gnome extensions
paru -S --noconfirm chrome-gnome-shell snap-pac-grub snapper-gui
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