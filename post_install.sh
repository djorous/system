#!/bin/bash
#------------------------------------------------------------------------------
# Configure Snapper
#------------------------------------------------------------------------------
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
cp /root/system/files/snapper.conf /etc/snapper/configs/snapper.conf
#Rename
mv /etc/snapper/configs/snapper.conf /etc/snapper/configs/root

#------------------------------------------------------------------------------
# Clean up
#------------------------------------------------------------------------------
#Delete the system folder
rm -rf /root/system

#------------------------------------------------------------------------------
# Restart Machine
#------------------------------------------------------------------------------
systemctl reboot