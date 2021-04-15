#!/bin/bash

check_dependency() {
	for cmd in "$@"; do
		if ! command -v $cmd >/dev/null 2>&1; then
			echo "This script requires \"${cmd}\" to be installed"
			return 1
		fi
	done
}

check_flatpak() {
	if ! check_dependency flatpak; then
		install_flatpak || return 1
	fi
}

echo_label() {
	echo && echo "Installing $1" && echo "---" && echo
}

append_to_file() {
	if [[ -e $FILE ]]; then
		for line in "$@"; do
			if [[ -z $line ]] || ! sudo cat $FILE | grep -q "$line"; then
				echo "$line" | sudo tee -a $FILE > /dev/null
			fi
		done

		# Delete all trailing blank lines at end of file
		# (https://unix.stackexchange.com/a/81687)
		sudo sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FILE
		echo | sudo tee -a $FILE > /dev/null
	else
		echo "Cannot append to '$FILE', file does not exist"
	fi
}

append_to_sources_list() {
	FILE="/etc/apt/sources.list"
	append_to_file "$@"
}

append_to_torrc() {
	FILE="/etc/tor/torrc"
	append_to_file "$@"
}

append_to_bash_aliases() {
	FILE="$HOME/.bash_aliases"
	append_to_file "$@"
}

uncomment_torrc() {
	FILE="/etc/tor/torrc"

	for string in "$@"; do
		sudo sed -i \
			"s/#\s\?\($string\)/\1/g" \
			$FILE
	done
}

get_latest_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" | 	# Get latest release from GitHub api
		grep '"tag_name":' |                                            # Get tag line
		sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

install_standard() {
	echo_label "standard tools"

	mkdir -p $HOME/Developer
	touch $$HOME/.commonrc

	sudo apt update && sudo apt install -y \
		htop \
		vim \
		tree \
		jq \
		git \
		vnstat \
		tmux \
		nmap
}

install_extraction_tools() {
	echo_label "extraction tools"

	sudo apt update

	# There are three 7zip packages in Ubuntu: p7zip, p7zip-full and p7zip-rar
	#
	# The difference between p7zip and p7zip-full is that p7zip is a lighter
	# version providing support only for .7z while the full version provides
	# support for more 7z compression algorithms (for audio files etc).
	#
	# The p7zip-rar package provides support for RAR files along with 7z.
	# Source: https://itsfoss.com/use-7zip-ubuntu-linux/
	sudo apt install -y p7zip-full p7zip-rar
}

install_snap() {
	echo_label "Snap"

	sudo apt update && sudo apt install -y snapd
	sudo snap install hello-world
}

install_flatpak() {
	echo_label "Flatpak"

	sudo add-apt-repository ppa:alexlarsson/flatpak
	sudo apt update && sudo apt install -y flatpak
}

install_vscode_apt() {
	# Note: on my Pop!OS system when the app updated itself
	#       via the Pop!_Shop it lost the 'code' binary
	#       in the terminal, so I switched to installing
	#       using Snap instead.

	echo_label "VS Code (via apt)"

	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
	rm packages.microsoft.gpg 
	sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

	sudo apt install apt-transport-https
	sudo apt update
	sudo apt install code # or code-insiders
}

install_vscode_snap() {
	echo_label "VS Code (via snap)"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install code --classic
}

install_speedtest() {
	echo_label "speedtest"

	sudo apt install -y gnupg1 apt-transport-https dirmngr
	export INSTALL_KEY=379CE192D401AB61
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
	echo "deb https://ookla.bintray.com/debian generic main" | sudo tee  /etc/apt/sources.list.d/speedtest.list
	sudo apt update

	# Other non-official binaries will conflict with Speedtest CLI
	# Example how to remove using apt-get
	# sudo apt remove speedtest-cli
	sudo apt install -y speedtest
}

install_magic_wormhole() {
	echo_label "Magic Wormhole"

	sudo apt update && \
		sudo apt install -y \
			magic-wormhole
}

install_fish() {
	echo_label "fish shell"

	sudo apt-add-repository -y ppa:fish-shell/release-3
	sudo apt update && sudo apt install -y fish
	echo && echo "Enter the password for current user '$USER' to change shell to 'fish'"
	chsh -s /usr/bin/fish

	FISH=$HOME/.config/fish
	mkdir -p $FISH
	touch $FISH/config.fish
	touch $HOME/.commonrc

	SOURCE_CMD="/bin/bash -c 'source $HOME/.commonrc'"
	if ! grep -q $SOURCE_CMD $FISH/config.fish; then
		echo $SOURCE_CMD >> $FISH/config.fish
	fi

	unset FISH
}

install_zsh() {
	echo_label "zsh"

	sudo apt update && sudo apt install -y zsh

	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	# echo && echo "Enter the password for current user '$USER' to change shell to 'Zsh'"
	# chsh -s $(which zsh)

	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	sed -i -E "s/(^plugins=.*)\)/\1 zsh-autosuggestions)/g" $HOME/.zshrc
}

install_telegram() {
	echo_label "Telegram"

	sudo apt update && sudo apt install -y telegram-desktop
}

install_signal() {
	echo_label "Signal Messenger"

	wget -O- https://updates.signal.org/desktop/apt/keys.asc \
		| sudo apt-key add -

	echo "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" \
		| sudo tee -a /etc/apt/sources.list.d/signal-xenial.list

	sudo apt update && sudo apt install -y signal-desktop
}

install_virtualbox() {
	echo_label "Virtualbox"

	# Switch to Method 3 here for latest: https://itsfoss.com/install-virtualbox-ubuntu/
	sudo apt update && sudo apt install -y virtualbox
}

install_vmware() {
	echo_label "VMWare"

	sudo apt update && sudo apt install -y \
		build-essential

	mkdir -p $HOME/Downloads
	pushd $HOME/Downloads > /dev/null
	wget \
		--user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0" \
		https://www.vmware.com/go/getplayer-linux

	chmod +x getplayer-linux
	sudo ./getplayer-linux
	popd > /dev/null

	echo
	echo "Open VMWare and make sure setup is complete in the UI"
	echo "-----"
	echo
}

install_windows_networking() {
	# Guide at: https://www.howtogeek.com/176471/how-to-share-files-between-windows-and-linux/
	echo_label "Windows Networking"

	sudo apt update && sudo apt install -y \
		cifs-utils

	echo "---"
	echo
	echo "Make a new dir and mount the Windows share to it like this:"
	echo "$ mkdir $HOME/Shared-Documents"
	echo "$ sudo mount.cifs //WindowsPC/Shared-Documents $HOME/Shared-Documents -o user=<Windows user here>"
	echo
}

install_1password() {
	echo_label "1password"

	sudo apt-key --keyring /usr/share/keyrings/1password.gpg adv --keyserver keyserver.ubuntu.com --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password.gpg] https://downloads.1password.com/linux/debian edge main' | sudo tee /etc/apt/sources.list.d/1password.list
	sudo apt update && sudo apt install -y 1password
}

install_tor_browser() {
	echo_label "Tor Browser"

	# Guide: https://itsfoss.com/install-tar-browser-linux/
	if ! check_flatpak; then
		echo "Couldn't find/install flatpak, skipping rest of install"
		return 1
	fi

	flatpak install -y flathub com.github.micahflee.torbrowser-launcher || \
		echo "If download was interrupted run: '$ flatpak repair --user'"

	flatpak run com.github.micahflee.torbrowser-launcher
}

install_tor() {
	echo_label "Tor daemon"

	TOR_URL="https://deb.torproject.org/torproject.org"

	sudo apt update && sudo apt install -y \
		dirmngr \
		apt-transport-https

	append_to_sources_list \
		"deb $TOR_URL buster main" \
		"deb-src $TOR_URL buster main"

	PGP_KEY="A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89"
	curl $TOR_URL/$PGP_KEY.asc | gpg --import
	gpg --export $PGP_KEY | sudo apt-key add -

	sudo apt update && sudo apt install -y \
		tor \
		tor-arm

	echo "Running '$ tor --version':"
	tor --version

	# 'torrc' edits from Raspibolt instructions
	# - https://stadicus.github.io/RaspiBolt/raspibolt_69_tor.html

	# echo "Editing '/etc/tor/torrc' file"
	# uncomment_torrc \
	# 	"ControlPort 9051" \
	# 	"CookieAuthentication 1"
	# append_to_torrc \
	# 	"# Added from Raspibolt instructions" \
	# 	"CookieAuthFileGroupReadable 1"

	# sudo systemctl restart tor
}

install_obsidian() {
	echo_label "Obsidian"

	if ! check_flatpak; then
		echo "Couldn't find/install flatpak, skipping rest of install"
		return 1
	fi

	flatpak install -y flathub md.obsidian.Obsidian || \
		echo "If download was interrupted run: '$ flatpak repair --user'"

	flatpak run md.obsidian.Obsidian
}

install_sensors() {
	echo_label "sensors"

	sudo apt update && sudo apt install -y lm-sensors hddtemp
	sudo sensors-detect

	sudo apt install -y psensor
}

install_docker_compose() {
	echo_label "Docker Compose"

	echo "Checking that Docker dependency is installed..."
	if ! command -v "docker"
	then
		echo "Docker not found, install first and then retry"
		return 1
	fi

	VERSION=$(get_latest_release "docker/compose")
	URL="https://github.com/docker/compose/releases/download/$VERSION/docker-compose-$(uname -s)-$(uname -m)"

	sudo curl -L $URL -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	docker-compose --version
}

install_docker() {
	# Guide at: https://docs.docker.com/engine/install/ubuntu/
	echo_label "Docker"

	# Remove any earlier versions
	sudo apt remove docker docker-engine docker.io containerd runc

	sudo apt update && sudo apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		gnupg-agent \
		software-properties-common

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	# Check for fetched key (https://docs.docker.com/engine/install/ubuntu/)
	sudo apt-key fingerprint 0EBFCD88

	sudo add-apt-repository -y \
		"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) \
		stable"

	sudo apt update && sudo apt install -y \
		docker-ce \
		docker-ce-cli \
		containerd.io

	echo && echo "Finished installing Docker, testing with 'hello world'..."
	sudo docker run hello-world

	# Setup Docker permissions for local user
	echo
	echo "Setting up local user permissions for Docker..."
	sudo groupadd docker
	sudo usermod -aG docker ${USER}
	su ${USER}
	docker run hello-world

	# Install docker-compose
	install_docker_compose
}

install_pyenv() {
	echo_label "pyenv"

	sudo apt update && sudo apt install -y \
		make build-essential libssl-dev zlib1g-dev \
		libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
		xz-utils tk-dev libffi-dev liblzma-dev \
		libxml2-dev libxmlsec1-dev
		# libncursesw5-dev python-openssl

	# Log script for manual double-check, optionally break function
	# -> see 'https://github.com/pyenv/pyenv-installer' for script
	SCRIPT="https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer"

	PARENT_SCRIPT="https://pyenv.run"
	echo && echo "Checking \$SCRIPT against parent script..."
	if curl -s $PARENT_SCRIPT | grep -q $SCRIPT; then
		echo "Check passed!"
		echo
	else
		echo "Check failed, re-check and correct in script"
		echo
		echo "Exiting 'pyenv' install..."
		echo
		return 1
	fi

	echo "Fetching install script for check before running from '$SCRIPT'" && echo
	echo
	SEP="================================"
	echo $SEP
	curl -L $SCRIPT
	echo $SEP
	echo
	read -p "Does script look ok to continue? (Y/n): " RESP
	echo
	if [[ $RESP == 'Y' ]] || [[ $RESP == 'y' ]]
	then
		echo "Starting 'pyenv' install"
	else
		echo "Skipping rest of 'pyenv' install"
		echo
		return 1
	fi

	# Proceed with pyenv install
	if ! command -v pyenv >/dev/null 2>&1
	then
		curl -L $SCRIPT | bash && \
		cat << 'EOF' >> $HOME/.commonrc 

# For pyenv
# Comment one of the following blocks

export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# if echo $SHELL | grep -q "/fish"
# 	set -x PATH "$HOME/.pyenv/bin" $PATH
# 	status --is-interactive; and . (pyenv init -|psub)
# 	status --is-interactive; and . (pyenv virtualenv-init -|psub)
# end
EOF

		echo "Reset shell to complete:"
		echo "\$ exec \"\$SHELL\""
		echo
	else
		echo "'pyenv' already installed"
	fi

	# Print instructions to install Python
	echo
	echo "Run the following next steps to install Python:"
	echo "$ pyenv install --list | grep \" 3\.\""
	echo "$ pyenv install -v <version>"

	# Add IPython manual fix note, can be removed after new IPython release
	echo
	echo "Note: IPython 7.19.0 has a tab autocompletion bug that is fixed by doing this: https://github.com/ipython/ipython/issues/12745#issuecomment-751892538"
	echo
}

install_thefuck() {
	if pip3 > /dev/null 2>&1
	then
		pip3 install thefuck
	else
		echo "Please install python3 and pip3 before trying to install 'thefuck'"
	fi
}

install_golang() {
	echo_label "GoLang"

	LATEST=$(REGEX=".*(go.*linux.*?gz).*"; curl -s https://golang.org/dl/ | grep -P $REGEX | sed -r "s/$REGEX/\1/" | head -n 1)

	VERSION=1.16
	ARCHITECTURE=linux-amd64
	GO_TARFILE=go$VERSION.$ARCHITECTURE.tar.gz

	echo "Installing '$GO_TARFILE' (latest is '$LATEST')"
	read -p "Continue? (Y/n): " RESP
	if ! [[ $RESP == 'Y' ]] && ! [[ $RESP == 'y' ]]; then
		echo "Skipping GoLang install..."
		return 1
	fi

	# Fetch tarfile
	DOWNLOAD_DIR=$HOME/Downloads
	mkdir -p $DOWNLOAD_DIR
	pushd $DOWNLOAD_DIR > /dev/null
	wget -c https://golang.org/dl/$GO_TARFILE

	SHA256SUM=$(sha256sum $GO_TARFILE)
	echo "Install file sha256sum:"
	echo "$SHA256SUM"
	echo

	# Install tarfile by unpacking
	sudo tar -C /usr/local -xzf $GO_TARFILE
	rm $GO_TARFILE
	popd > /dev/null

	# Add binary to $PATH
	COMMONRC=$HOME/.commonrc
	if [ -f $COMMONRC ]; then
		echo >> $COMMONRC
		echo "# For GoLang" >> $COMMONRC
		echo "export PATH=\$PATH:/usr/local/go/bin" >> $COMMONRC
		echo >> $COMMONRC
	else
		echo "Add the following to your shell profile:"
		echo "	export PATH=\$PATH:/usr/local/go/bin"
		echo
	fi

	echo "Finished installing GoLang v$VERSION"

	# To uninstall, simply delete the created directory '/usr/local/go' and
	# remove the 'go' binary from being added to $PATH
	# Instructions: https://golang.org/doc/manage-install#linux-mac-bsd
}

install_awscli() {
	echo_label "AWS CLI"

	VIRTUALENV="awscli"
	INSTALL_DIRNAME="aws-cli"
	REPO=https://github.com/aws/$INSTALL_DIRNAME.git

	# Fetch install files
	git clone $REPO
	pushd $INSTALL_DIRNAME > /dev/null
	git checkout v2

	# Check virtualenv dependency
	if check_dependency pyenv; then
		echo "Creating '$VIRTUALENV' virtualenv with pyenv"
		pyenv virtualenv $VIRTUALENV
		pyenv local $VIRTUALENV
		pip install --upgrade pip
	else
		echo 
		read -p "No 'pyenv' found, would you like to proceed with system Python? (Y/n): " RESP
		echo
		if [[ $RESP == 'N' ]] || [[ $RESP == 'n' ]]; then
			echo "Skipping rest of awscli install..."
			return 1
		fi
	fi

	# Install awscli
	pip3 install -r requirements.txt
	pip3 install .

	echo
	echo "Checking for 'aws' binary..."
	if aws --version; then
		echo "AWS CLI installed"
		echo
		echo "Configure using the following command:"
		echo "$ aws configure"
	else
		echo "Error: double-check that '$ aws' command works"
		return 1
	fi

	# Cleanup
	popd > /dev/null
	rm -rf $INSTALL_DIRNAME

	# Add to aliases
	if check_dependency pyenv; then
		append_to_bash_aliases \
			"" \
			"# AWS CLI virtualenv" \
			"alias aws=\"$HOME/.pyenv/versions/$VIRTUALENV/bin/aws\""
	fi
}

test_lines() {
	cat << 'EOF' >> $HOME/.commonrc 

# For pyenv
# Comment one of the following blocks

# if echo $SHELL | grep -q "/bash"
# then
# 	export PATH="$HOME/.pyenv/bin:$PATH"
# 	eval "$(pyenv init -)"
# 	eval "$(pyenv virtualenv-init -)"
# fi

if echo $SHELL | grep -q "/fish"
	set -x PATH "$HOME/.pyenv/bin" $PATH
	status --is-interactive; and . (pyenv init -|psub)
	status --is-interactive; and . (pyenv virtualenv-init -|psub)
end
EOF

}

install_yubikey() {
	# Followed guide at: https://blog.programster.org/yubikey-link-with-gpg
	echo_label "Yubikey dependencies"

	sudo apt update && sudo apt install -y \
		pcscd \
		scdaemon \
		gnupg2
		# pcsc-tools
}

install_slack() {
	echo_label "Slack"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install slack --classic
}

install_spotify() {
	echo_label "Spotify"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install spotify
}

install_keybase() {
	curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
	sudo apt install -y ./keybase_amd64.deb
	run_keybase

	rm keybase_amd64.deb
}

install_rpi_imager() {
	echo_label "RPi Imager"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install rpi-imager
}

install_vlc() {
	echo_label "VLC Media Player"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install vlc
}

install_qbittorrent() {
	echo_label "qbittorrent"

	sudo apt update && sudo apt install -y qbittorrent
}

install_peek_gif_recorder() {
	echo_label "peek (GIF screen recorder)"

	if ! check_flatpak; then
		echo "Couldn't find/install flatpak, skipping rest of install"
		return 1
	fi

	if flatpak install -y flathub com.uploadedlobster.peek; then
		flatpak run com.uploadedlobster.peek
	else
		echo "If download was interrupted run: '$ flatpak repair --user'"
	fi

}

install_dropbox() {
	echo_label "Dropbox"

	# cd $HOME && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -

	# echo "Starting Dropbox"
	# echo "---"
	# $HOME/.dropbox-dist/dropboxd

	# Add to aliases
	append_to_bash_aliases \
		"" \
		"# Dropbox" \
		"alias dropbox=\"$HOME/.dropbox-dist/dropboxd\""
}

install_gparted() {
	echo_label "GParted"

	sudo apt update && sudo apt install -y gparted
}

install_noip() {
	echo_label "No-IP DUC"

	INSTALL_DIR=$HOME/Installs/noip
	TAR_FILE=https://www.noip.com/client/linux/noip-duc-linux.tar.gz
	LOCAL_FILE=noip-duc-linux.tar.gz

	mkdir -p $INSTALL_DIR
	pushd $INSTALL_DIR > /dev/null
	wget -O $LOCAL_FILE $TAR_FILE
	tar xvzf $LOCAL_FILE
	rm $LOCAL_FILE

	pushd $(ls) > /dev/null

	# Make started to give some problems with a 'sprintf overflow'
	# error; skipping seems ok
	# sudo make

	sudo make install

	unset INSTALL_DIR
	unset TAR_FILE
	unset LOCAL_FILE

	# Setup systemd service
	echo "Setting up systemd service for noip duc"
	LOCAL_SERVICE_FILE=/etc/systemd/system/noip2.service
	NOIP_SERVICE_FILE=https://gist.githubusercontent.com/vindard/0205001d13665eff809c30c0fe9cf487/raw/05ef5777b0341337665e39afea22df62dd8c4106/noip2.service
	sudo wget -O $LOCAL_SERVICE_FILE $NOIP_SERVICE_FILE

	sudo systemctl enable noip2
	sudo systemctl start noip2
}

install_expressvpn() {
	echo "Follow instructions at https://www.expressvpn.com/support/vpn-setup/app-for-linux/#install"
}

install_wireguard() {
	echo_label "Wireguard"

	sudo apt update && sudo apt install -y wireguard

	WIREGUARD_DIR=/etc/wireguard
	echo
	echo "Generating wireguard keys"
	wg genkey | sudo tee $WIREGUARD_DIR/privatekey | wg pubkey | sudo tee $WIREGUARD_DIR/publickey
	echo "Keys generated at $WIREGUARD_DIR"
	echo "Finished installing wireguard, configure the 'wgo0.conf' file at $WIREGUARD_DIR to use"
	echo
}

install_electrum() {
	echo_label "Electrum"

	# Fetch Thomas' pgp keys
	echo "Fetching Thomas' PGP keys"
	gpg --recv-keys \
		--keyserver pgp.mit.edu \
		6694D8DE7BE8EE5631BED9502BD5824B7F9470E6

	# Fetch install files
	VERSION=4.0.9
	BASE_FILE=Electrum-$VERSION.tar.gz
	wget https://download.electrum.org/$VERSION/$BASE_FILE
	wget https://download.electrum.org/$VERSION/$BASE_FILE.asc
	gpg --verify $BASE_FILE.asc

	# Install dependencies
	sudo apt update && sudo apt install -y \
		python3-pyqt5 \
		libsecp256k1-0 \
		python3-cryptography

	# Install python dependencies
	sudo apt install -y \
		python3-setuptools \
		python3-pip

	# Install Electrum from package using pip
	python3 -m pip install --user $BASE_FILE

	rm $BASE_FILE*
	$HOME/.local/bin/electrum version --offline

	# Add binary to $PATH
	COMMONRC=$HOME/.commonrc
	if [ -f $COMMONRC ]; then
		echo >> $COMMONRC
		echo "# For Electrum" >> $COMMONRC
		echo "export PATH=\$PATH:$HOME/.local/bin" >> $COMMONRC
		echo >> $COMMONRC
	else
		echo "Add the following to your shell profile:"
		echo "	export PATH=\$PATH:$HOME/.local/bin"
		echo
	fi

	echo
	echo "Finished installing Electrum. Restart shell and check with '\$ electrum --version'" 
}

install_udev_deps() {
	sudo apt update && sudo apt install -y \
		libusb-1.0-0-dev \
		libudev-dev

	sudo groupadd plugdev
	sudo usermod -aG plugdev $(whoami)
}

install_trezor_udev() {
	echo_label "Trezor Hardware wallet"
	install_udev_deps

	python3 -m pip install trezor[hidapi]

	cat << 'EOF' | sudo tee /etc/udev/rules.d/51-trezor.rules
# Trezor: The Original Hardware Wallet
# https://trezor.io/
#
# Put this file into /etc/udev/rules.d
#
# If you are creating a distribution package,
# put this into /usr/lib/udev/rules.d or /lib/udev/rules.d
# depending on your distribution

# Trezor
SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# Trezor v2
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"
EOF

	sudo udevadm control --reload-rules && \
		sudo udevadm trigger
}

install_zap_wallet() {
	echo_label "Zap Desktop"


	VERSION="v0.7.2-beta"
	FILE="Zap-linux-x86_64-$VERSION.AppImage"
	INSTALL_DIR="$HOME/Installs"
	URL=https://github.com/LN-Zap/zap-desktop/releases/download/$VERSION/$FILE
	echo "Installing hardcoded version '$VERSION'"

	mkdir -p $INSTALL_DIR
	pushd $INSTALL_DIR > /dev/null
	wget $URL

	sudo chmod +x $FILE
	popd > /dev/null

	# Add to aliases
	append_to_bash_aliases \
		"" \
		"# Zap Wallet" \
		"alias zap=\"$INSTALL_DIR/$FILE && exit\""

	echo "Finished installing, restart shell and run '$ zap' to execute"
}

install_chromium() {
	echo_label "Chromium Browser"

	sudo apt update && sudo apt install -y chromium-browser
}


install_hdparm() {
	echo_label "hdparm"

	sudo apt update && sudo apt install -y \
		hdparm
}
configure_git() {
	echo_label "git configuration"

	git config --global user.name "vindard"
	git config --global user.email "17693119+vindard@users.noreply.github.com"

	echo
	echo "To import 'hot' signing keys fetch the following file and run:"
	echo "$ gpg --decrypt 8F95D90A-priv_subkeys-GHonly.gpg.asc | gpg --import"
	echo "$ git config --global user.signingkey 1B005D838F95D90A"
	echo "$ git config --global commit.gpgsign true"
}

add_ed25519_ssh_key() {
	echo_label "new ed25519 SSH keypair"

	ssh-keygen -o -a 100 -t ed25519
}


# Run the installs

# install_standard
# install_extraction_tools
# install_vscode_apt
# install_vscode_snap
# install_speedtest
# install_magic_wormhole
# install_fish
# install_zsh
# install_telegram
# install_signal
# install_virtualbox
# install_vmware
# install_windows_networking
# install_1password
# install_tor_browser
# install_tor
# install_obsidian
# install_sensors
# install_docker
# install_pyenv
# install_thefuck
# install_golang
# install_awscli
# install_yubikey
# install_slack
# install_spotify
# install_keybase
# install_rpi_imager
# install_vlc
# install_gparted
# install_noip
# install_expressvpn
# install_wireguard
# install_electrum
# install_trezor_udev
# install_zap_wallet
# install_chromium
# install_hdparm
# install_qbittorrent
# install_peek_gif_recorder
# install_dropbox
# configure_git
# add_ed25519_ssh_key

# test_lines
