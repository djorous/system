#!/bin/bash
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' | fdisk /dev/sda
g
n
1

+512M
n
2

+4G
n
3

+25G
n
4


t
1
uefi
t
2
swap
p
w
q
