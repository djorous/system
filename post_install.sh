#!/bin/bash
#------------------------------------------------------------------------------
# Configure Snapper
#------------------------------------------------------------------------------
#Chroot into installation
umount /.snapshots
rm -r /.snapshots
snapper -c default create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a 
chmod a+rx /.snapshots
chmod :wheel /.snapshots