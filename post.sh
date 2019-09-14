# Install yay
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Install yadm
yay -S --noconfirm yadm-git

# Pull settings from git
yadm clone https://github.com/morten-b/dotfiles.git
