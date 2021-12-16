#!/bin/bash
#------------------------------------------------------------------------------
# Configure Snapper
#------------------------------------------------------------------------------
#Install packages
pacman --noconfirm -Syu
pacman --noconfirm -S snapper snap-pac
#Umount the snapshots folder
umount /.snapshots
rm -r /.snapshots
#Create snapper configuration
snapper -c root create-config /
#Remove the newly created subvolume
btrfs subvolume delete /.snapshots
#Recreate folders
mkdir /.snapshots
#Remount the folders
mount -a 
#Adjust permissions
chmod 750 /.snapshots
#Adjust configurations
mv /etc/snapper/configs/root /etc/snapper/configs/root_original
#Move configuration file
cp /root/system/files/snapper.conf /etc/snapper/configs/
#Rename
mv /etc/snapper/configs/snapper.conf /etc/snapper/configs/root

#------------------------------------------------------------------------------
# Enable Services
#------------------------------------------------------------------------------
systemctl enable snapper-timeline.timer
systemctl enable snapper-boot.timer
systemctl enable snapper-cleanup.timer

#------------------------------------------------------------------------------
# Configure UpdateDB for Snaps
#------------------------------------------------------------------------------
#Rename Original configuration
mv /etc/updatedb.conf /etc/updatedb.conf_original
#Adjust configurations
cp /root/system/files/updatedb.conf /etc/updatedb.conf
#Refresh db
updatedb

#------------------------------------------------------------------------------
# Clean up
#------------------------------------------------------------------------------
#Delete the system folder
rm -rf /root/system

#------------------------------------------------------------------------------
# Restart Machine
#------------------------------------------------------------------------------
systemctl reboot