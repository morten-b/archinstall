git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Install yadm
yay -S yadm-git

# Pull settings from git
yadm clone https://github.com/morten-b/dotfiles.git
