#!/bin/bash
# bash > 4.5.1  ??? explain this

EXIT="0"

error() {
	# description: print error message and exit with code
	# args: $1 - message
	#       $2 - error code (optional)
	EXIT="1"
	echo -e "\e[31m[ER] $1\e[m"
	[ -z "$2" ] || exit "$2"
}

success() {
	# description: print success message
	# args: $1 - message
	echo -e "\e[32m[OK] $1\e[m"
}

announce() {
	# description: print step anounce message
	# args: $1 - message
	echo -e "\e[34m[..] $1\e[m"
}

draw_dialog() {
	# description: draw dialog box using dialog, install dialog prior to use
	# args: $1 - title
	#       $2 - message
	dialog --title "\Z1$1" \
		--no-collapse --no-lines --no-shadow --erase-on-exit --colors \
		--msgbox "\Z1\Zb$2" 25 100
	clear
}

get_settings_value() {
	# desciption: returns json value by filter,
	#             should be used after $SETTING_FILE definition
	# args: $1 - jq filter
	jq -re "$1" "$SETTINGS_PATH" 2>/dev/null
}

# Read JSON
SETTINGS_PATH="/deploy/settings.json"
# Install jq
[ "$(whoami)" = "root" ] && pacman -Suy jq --noconfirm 1>/dev/null
# Check if file exitst and is valid json
jq -re "." "$SETTINGS_PATH" 1>/dev/null || exit 1

# Create setting associative array
declare -A settings
settings["user_name"]="$(get_settings_value ".user.name")"

settings["dotfiles_git"]="$(get_settings_value ".dotfiles.git")"
settings["dotfiles_dir"]="$(get_settings_value ".dotfiles.dir")"
settings["dotfiles_branch"]="$(get_settings_value ".dotfiles.branch")"

settings["scripts_git"]="$(get_settings_value ".scripts.git")"
settings["scripts_path"]="$(get_settings_value ".scripts.path")"

settings["docker_data_path"]="$(get_settings_value ".docker.data_path")"

# Add additional variables make code shorter
settings["user_home"]="/home/${settings[user_name]}"
settings["dotfiles_path"]="/home/${settings[user_home]}/${settings[dotfiles_dir]}"

# Print settings (useful for debug)
# for key in "${!settings[@]}"; do
# 	echo "$key - ${settings[$key]}"
# done

# Check for missing and empty keys in settings
for key in "${!settings[@]}"; do
	[ -z "${settings[$key]}" ] && EXIT="yes"
	[ "${settings[$key]}" = "null" ] && error "Property \"$key\" missing from settings"
	[ -z "${settings[$key]}" ] && error "\"$key\" property should not be empty"
done

# Exit if any emoty value or missing key found
[ "$EXIT" = "1" ] && exit 1

# Steps
pacman_setup() { # root
	announce "Configuring pacman"
	# Enable colors
	sed "/#Color = /s/^#//g" -i /etc/pacman.conf

	success "Configuring pacman"
}

nm_setup() { # root
	announce "Configuring NetworkManager"

	pacman -Suy dhcpcd networkmanager --noconfirm &>/dev/null

	success "Configuring NetworkManager"
}

user_setup() { # root
	announce "Configuring user"

	pacman -Suy sudo vi zsh zsh-autosuggestions zsh-syntax-highlighting dialog --noconfirm &>/dev/null

	draw_dialog "Sudo" \
		"Now you will be redirected to visudo to edit sudoers file. Editor is vi.\n
If you don't know what this all about check ArchWiki sudo page.\n
Make sure to use wheel group and not sudo because it will break your sudo command."

	visudo

	# Set root password
	draw_dialog "Password" "Now you will be prompted to enter password for root user."
	passwd

	# Set user password
	useradd -m -G wheel "${settings[user_name]}" -s /bin/zsh &>/dev/null
	draw_dialog "Password" "Now you will be prompted to enter password for your new user \"${settings[user_name]}\"."
	passwd "${settings[user_name]}"

	clear
	success "Configuring user"
}

docker_setup() { # root
	announce "Configuring Docker"

	pacman -Suy docker docker-compose --noconfirm 1>/dev/null

	mkdir -p /etc/docker
	echo "{ \"data-root\": \"/${settings[docker_data_path]}\" }" >>/etc/docker/daemon.json

	systemctl enable docker.service

	success "Configuring Docker"
}

dotfiles_deploy() { # root
	announce "Deploying dotfiles"

	pacman -Suy git --noconfirm &>/dev/null

	mkdir -p "${settings[user_home]}"

	echo "${settings[dotfiles_dir]}" >>.gitignore

	rm -rf "${settings[dotfiles_path]}"
	git clone --bare "${settings[dotfiles_git]}" "${settings[dotfiles_path]}" &>/dev/null

	git --git-dir="${settings[dotfiles_path]}" --work-tree="${settings[user_home]}" checkout "${settings[dotfiles_branch]}" &>/dev/null
	git --git-dir="${settings[dotfiles_path]}" --work-tree="${settings[user_home]}" config --local status.showUntrackedFiles no &>/dev/null

	success "Deploying dotfiles"
}

scripts_deploy() { # user
	announce "Deploying scripts"

	cd "${settings[user_home]}" || exit 1
	mkdir -p "${settings[scripts_path]}"

	git clone "${settings[scripts_git]}" "${settings[scripts_path]}" &>/dev/null

	success "Deploying scripts"
}

yay_setup() { # user
	announce "Installing Yay"
	sudo pacman -Suy base-devel --needed --noconfirm &>/dev/null

	git clone https://aur.archlinux.org/yay-bin.git YAY &>/dev/null
	cd YAY || exit 1

	makepkg -si --noconfirm 1>/dev/null

	cd "${settings[user_home]}" || exit 1
	rm -rf YAY

	success "Installing Yay"
}

node_npm_setup() { # user
	announce "Installing nodejs, npm, pnpm"

	sudo pacman -Suy nodejs npm --noconfirm &>/dev/null
	yay -Suy pnpm-bin --noconfirm --sudoloop &>/dev/null

	success "Installing nodejs, npm, pnpm"
}

neovim_bootstrap() { # user
	announce "Bootstraping Neovim"

	yay -Suy neovim-nightly-bin luajit --noconfirm --sudoloop &>/dev/null
	draw_dialog "Neovim" "Now neovim will be bootstraped. Just wait until all plugins are installed and then close neovim.\n
Don't worry if one or more plugins fail during process.\n
it seems to happen for no reason for some plugins when bootstrapping)."
	nvim

	success "Bootstraping Neovim"
}

locale_setup() {
	# TODO: Take locales list from settings file
	announce "Configuring locales"

	sed "/#en_US\.UTF-8/s/^#//g" -i /etc/locale.gen
	sed "/#uk_UA\.utf8/s/^#//g" -i /etc/locale.gen

	locale-gen &>/dev/null

	success "Configuring locales"
}

# x11_wm() { # user
# 	# TODO: Make new git repo for suckless tools and deploy them in a better way
# 	yay -Suy libxft-bgra --noconfirm
# 	rm -rf "$DWM_REPO_PATH"
# 	mkdir -p "$DWM_REPO_PATH"
# 	git clone "$DWM_REPO_GIT_URL" "$DWM_REPO_PATH"
# 	cd "$DWM_REPO_PATH" || exit 1
# 	sudo make install
# 	cd "$USER_HOME" || exit 1
# }
#
# x11_fonts_setup() { # user
# 	echo "fonts"
# }
#
# x11_intel() { # user
# 	sudo pacman -Suy xf86-video-intel vulkan-intel
# }
#
# x11_amdgpu() { # user
# 	sudo pacman -Suy xf86-video-amdgpu amdvlk
# }
#
# x11_apps_setup() {
# 	sudo pacman -Suy alacritty htop --noconfirm
# }
#
# x11_setup() { # user
# 	sudo pacman -Suy xorg-server xorg-xwininfo xorg-xprop xorg-xinit xorg-xsetroot hsetroot libx11 libxcb fontconfig --noconfirm
# 	# TODO: Make settings option to select graphics driver
# 	x11_intel
# 	x11_amdgpu
# 	x11_fonts_setup
# 	x11_apps_setup
# 	x11_wm
# }

# NOTE
#   If any step in root or user section fails
#   just comment completed ones in functions below and run it again. 🤡
#   By the way, it's better not to change the order of steps because some of them depend on sequence.
root_section() {
	announce "Deploying everything..."
	locale_setup
	pacman_setup
	nm_setup
	user_setup
	docker_setup
	dotfiles_deploy
	# Execute user section
	su -l "${settings[user_name]}" <<EOF
bash /deploy/deploy.sh
EOF
	su -l "${settings[user_name]}"
}

user_section() {
	scripts_deploy
	yay_setup
	node_npm_setup
	neovim_bootstrap
	# x11_setup
	echo -e "\e[32mSuccessfully finished!\e[m"
}

# Determine which section to run
case $("whoami") in
"root") root_section ;;
"${settings[user_name]}") user_section ;;
*) error "Username from whoami do not match one from \"$SETTINGS_FILE\"" "1" ;;
esac
