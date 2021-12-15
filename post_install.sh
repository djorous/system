#!/bin/bash
#------------------------------------------------------------------------------
# Enable Snapper Services
#------------------------------------------------------------------------------ 
 pacman -S --noconfirm snapper snap-pac
#------------------------------------------------------------------------------
# Configure Snapper
#------------------------------------------------------------------------------
#Umount the snapshots folder
umount /.snapshots
rm -r /.snapshots
#Create snapper configuration
snapper -c default create-config /
#Remove the newly created subvolume
btrfs subvolume delete /.snapshots
#Recreate folders
mkdir /.snapshots
#Remount the folders
mount -a 
#Adjust permissions
chmod 750 /.snapshots
chmod a+rx /.snapshots
chown :wheel /.snapshots

#------------------------------------------------------------------------------
# Enable Snapper Services
#------------------------------------------------------------------------------
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer

#Install gnome extensions
paru -S --noconfirm chrome-gnome-shell 