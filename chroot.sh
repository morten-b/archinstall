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
passwd morten

grub-install

# Configure mkinitcpio with modules needed for the initrd image
echo -e ""
echo -e ">>  EDIT MKINITCPIO.CONF"
echo -e "    --------------------"
echo -e ""
echo -e "Add \'encrypt\' and \'lvm2\' to HOOKS before filesystems"
echo -e "Add \'ext4\' to MODULES"
echo -e ""
echo -n "Press [ENTER] to continue..."
read ret
nano /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux

# Enable sudo for user
sed -i 's/#%wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers

# Make keyboard layout persistent
localectl set-x11-keymap dk

# Install Yay
sudo pacman -Syu
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Install yadm
yay -S yadm-git

# Pull settings from git
yadm clone https://github.com/morten-b/dotfiles.git
