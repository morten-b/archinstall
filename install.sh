#!/bin/bash

echo -e "\nFormatting disk...\n$HR"

# disk prep
sgdisk -Z /dev/sda # zap all on disk
sgdisk -a 2048 -o /dev/sda # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+100M /dev/sda # partition 1 (EFI), default start block, 200MB
sgdisk -n 2:0:+250M /dev/sda # partition 2 (Boot), default start block, 200MB
sgdisk -n 3:0:0 /dev/sda # partition 3, (Encrypted), default start, remaining space

# set partition types
sgdisk -t 1:ef00 /dev/sda
sgdisk -t 2:8300 /dev/sda
sgdisk -t 3:8300 /dev/sda

# label partitions
sgdisk -c 1:"EFI" /dev/sda
sgdisk -c 2:"BOOT" /dev/sda
sgdisk -c 3:"LUKS" /dev/sda

mkfs.vfat -F32 /dev/sda1
mkfs.ext2 /dev/sda2

# Setup the encryption of the system
cryptsetup -c aes-xts-plain64 -y --use-random luksFormat /dev/sda3
cryptsetup luksOpen /dev/sda3 luks

# Create encrypted partitions
pvcreate /dev/mapper/luks
vgcreate vg0 /dev/mapper/luks
lvcreate --size 8G vg0 --name swap
lvcreate -l +100%FREE vg0 --name root

# Create filesystems on encrypted partitions
mkfs.ext4 /dev/mapper/vg0-root
mkswap /dev/mapper/vg0-swap

# Mount the new system 
mount /dev/mapper/vg0-root /mnt # /mnt is the installed system
swapon /dev/mapper/vg0-swap # Not needed but a good thing to test
mkdir /mnt/boot
mount /dev/sdX2 /mnt/boot
mkdir /mnt/boot/efi
mount /dev/sdX1 /mnt/boot/efi

echo -e "\nAdjust mirrors...\n$HR"
# Adjust mirrors
pacman -Syu
pacman -S reflector
reflector —verbose —latest 5 —country ‘Denmark’ —sort rate —save /etc/pacman.d/mirrorlist

echo -e "\nInstalling...\n$HR"
# Install the system
pacstrap /mnt base base-devel grub-efi-x86_64 fish git efibootmgr dialog wpa_supplicant

# 'install' fstab
genfstab -pU /mnt >> /mnt/etc/fstab

echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >> /mnt/etc/fstab
