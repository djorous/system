
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

#------------------------------------------------------------------------------
# Install AUR snapper packages
#------------------------------------------------------------------------------ 
#Install gnome extensions
paru -S --noconfirm 