#!/bin/bash

#!/bin/bash

#### Password prompts ####
echo "Encrypt password:"
read encryption_passphrase
echo "Root password:" 
read root_password
echo "User password:"
read user_password

swap_size="16" # same as ram if using hibernation, otherwise minimum of 8

echo "Updating system clock"
timedatectl set-ntp true

echo "Syncing packages database"
pacman -Sy --noconfirm

echo "Creating partition tables"
printf "n\n1\n4096\n+512M\nef00\nw\ny\n" | gdisk /dev/sda
printf "n\n2\n\n\n8e00\nw\ny\n" | gdisk /dev/sda

echo "Setting up cryptographic volume"
printf "%s" "$encryption_passphrase" | cryptsetup -h sha512 -s 512 --use-random --type luks2 luksFormat /dev/sda
printf "%s" "$encryption_passphrase" | cryptsetup luksOpen /dev/sda cryptlvm

echo "Creating physical volume"
pvcreate /dev/mapper/cryptlvm

echo "Creating volume volume"
vgcreate vg0 /dev/mapper/cryptlvm

echo "Creating logical volumes"
lvcreate -L +"$swap_size"GB vg0 -n swap
lvcreate -l +100%FREE vg0 -n root

echo "Setting up / partition"
yes | mkfs.ext4 /dev/vg0/root
mount /dev/vg0/root /mnt

echo "Setting up /boot partition"
yes | mkfs.fat -F32 /dev/sda
mkdir /mnt/boot
mount /dev/sda /mnt/boot

echo "Setting up swap"
yes | mkswap /dev/vg0/swap
swapon /dev/vg0/swap

#Adjust mirrors
pacman -Sy --noconfirm reflector
reflector --verbose --latest 5 --country Denmark --sort rate --save /etc/pacman.d/mirrorlist

# Install the system
pacstrap /mnt base base-devel grub-efi-x86_64 fish git efibootmgr dialog wpa_supplicant

# 'install' fstab
genfstab -pU /mnt >> /mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >> /mnt/etc/fstab

# Setup system
arch-chroot /mnt /bin/bash <<EOF

# Setup system clock
ln -sf /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime
hwclock --systohc --utc

# Set the hostname
echo thinkpad > /etc/hostname

# Setting locale
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
sed -i 's/#en_DK.UTF-8 UTF-8/en_DK.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# Update locale
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANGUAGE=en_US >> /etc/locale.conf
echo LC_ALL=C >> /etc/locale.conf

# Set password for root
echo "${root}" | passwd --stdin root

# Add real user
useradd -m -g users -G wheel -s /usr/bin/fish morten
echo "${root}" | passwd --stdin morten

# Configure mkinitcpio with modules needed for the initrd image
sed -i 's/^MODULES.*/MODULES=(ext4)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS.*/HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck"/' /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux

# Setup grub
grub-install
sed -i 's|^GRUB_CMDLINE_LINUX="".*|GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:luks:allow-discards"|' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Enable sudo for user
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers

# Make keyboard layout persistent
localectl set-keymap dk

# Exit new system and go into the cd shell
exit

EOF

# Unmount all partitions
umount -R /mnt
swapoff -a

# Reboot into the new system, don't forget to remove the cd/usb
reboot
