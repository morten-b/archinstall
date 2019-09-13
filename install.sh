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
mount /dev/sda2 /mnt/boot
mkdir /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

echo -e "\nAdjust mirrors...\n$HR"
#Adjust mirrors
pacman -Sy --noconfirm reflector
reflector --verbose --latest 5 --country Denmark --sort rate --save /etc/pacman.d/mirrorlist

echo -e "\nInstalling...\n$HR"
# Install the system
pacstrap /mnt base base-devel grub-efi-x86_64 fish git efibootmgr dialog wpa_supplicant

# 'install' fstab
genfstab -pU /mnt >> /mnt/etc/fstab

echo "tmpfs	/tmp	tmpfs	defaults,noatime,mode=1777	0	0" >> /mnt/etc/fstab

echo -e "bash <(curl -S https://github.com/morten-b/archinstall/edit/master/chroot.sh)"
echo -e "arch-chroot /mnt /bin/bash"

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

echo -e ">>  ROOT PASSWORD"
# Set password for root
passwd

# Add real user remove -s flag if you don't whish to use zsh
useradd -m -g users -G wheel -s /usr/bin/fish morten
echo -e ">>  USER PASSWORD"
passwd morten

# Configure mkinitcpio with modules needed for the initrd image
sed -i 's/^MODULES.*/MODULES=(ext4)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS.*/HOOKS="base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck"/' /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux

# Setup grub
grub-install
sed -i 's|^GRUB_CMDLINE_LINUX="".*|GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:luks:allow-discards"|' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

arch-chroot /mnt /bin/bash <<EOF
# Enable sudo for user
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers

# Make keyboard layout persistent
# localectl set-x11-keymap dk

# Install Yay
pacman -Syu

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Install yadm
yay -S --noconfirm yadm-git

# Pull settings from git
yadm clone https://github.com/morten-b/dotfiles.git

echo -e "bash <(curl -S https://raw.githubusercontent.com/morten-b/archinstall/master/post.sh)"
echo -e "su - morten"
echo -e "nano /etc/mkinitcpio.conf"

# Exit new system and go into the cd shell
exit

EOF

# Unmount all partitions
umount -R /mnt
swapoff -a

# Reboot into the new system, don't forget to remove the cd/usb
reboot
