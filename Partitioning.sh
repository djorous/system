#!/bin/bash
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' | fdisk /dev/sda
  g     # clear the in memory partition table
  n     # new partition
  1     # partition number 1
        # default - start at beginning of disk 
  +512M # 100 MB boot parttion
  n     # new partition
  2     # partion number 2
        # default, start immediately after preceding partition
  +4G   # default, extend partition to end of disk
  n     # new partition
  3     # partion number 2
        # default, start immediately after preceding partition
  +25G  # default, extend partition to end of disk
  n     # new partition
  4     # partion number 2
        # default, start immediately after preceding partition
        # default, extend partition to end of disk
  t     # change type
  1     # partition number 1
  uefi  # partition type
  t     # change type
  2     # partition number 1
  swap  # partition type
  p     # print the in-memory partition table
  w     # write the partition table
