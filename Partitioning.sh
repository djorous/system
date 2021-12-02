#!/bin/bash
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
  +45G # swap partition
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
