#!/bin/bash

# list of packages that should be installed immediately
packages="
git
vim
python3
python3-pip
tmux
"

# keys are stored one per file in the format `idrsa_user@host_YYYY.MM.DD`
sshkey_repo="git@github.com:txoof/ssh_keys.git"

# dotfiles are stored here
dotfile_repo="git@github.com:txoof/Dotfiles.git"

# this appears to be important for dtparam -- enabling spi
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf


# change the default password
ch_password () {
	echo "setting password..."
	passwd
	echo " "
}

# install packages
install_pkgs () {
	echo "updating and installing packages"
	sudo apt-get update
	sudo apt-get ---with-new-pkgs --assume-yes upgrade
	sudo apt-get --assume-yes install $packages
}

# set the hostname
host_name () {
	CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
	read -p "Please enter a new hostname: " NEW_HOSTNAME
	if [[ $NEW_HOSTNAME ]]; then
		echo $NEW_HOSTNAME | sudo tee -a /etc/hostname
		sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
		read -t 10 -p "Reboot in 10 Seconds N/y: " REBOOT
		case $REBOOT in
			[yY]* ) sudo shutdown -r now;;
			[nN]* ) echo "please reboot for hostname changes to take effect";;
		esac
	fi
}

# pull the ssh keys from the github repo and build the autorized_keys file
ssh_keys () {
	#ssh-keygen -f ~/.ssh/id_rsa
	echo "Add this key to github now at this link:
	https://github.com/settings/ssh/new
	"
	cat ~/.ssh/id_rsa.pub
        read -p "
        press any key to continue...
        "
        echo "preparing authorized_keys..."
        pushd /tmp/
        git clone $sshkey_repo
        dirName=$(basename $sshkey_repo | cut -f 1 -d '.')
        pushd $dirName
        cat idrsa* >> ~/.ssh/authorized_keys
        popd
        popd
        echo "cleaning up"
        rm -rf /tmp/ssh_keys
}

# sync dotfiles
dot_files () {
	pip3 install dotfiles
	pushd ~/
	git clone $dotfile_repo
        ln -s ~/Dotfiles/dotfilesrc ~/.dotfilesrc
	/home/pi/.local/bin/dotfiles -s --force
	. .bashrc
	popd
}

# enable spi
spi_setup () {
  echo "enabling SPI"
  if ! [ -e $BLACKLIST ]; then
    sudo touch $BLACKLIST
  fi
  sudo sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*spi[-_]bcm2708\)/#\1/"
  sudo dtparam spi=on
}

static_ip () {
  interfaces=()
  echo "choose an interface for a static IP"
  for iface in $(ifconfig | cut -d ' ' -f1 | tr ':' '\n'|awk NF)
  do
    printf "$iface\n"
    interfaces+=("$iface")
  done
  iface="None"
  printf "$iface\n"

  interfaces+=("$iface")
  
  echo ${interfaces}
  contains () {
    typeset _x;
    typeset -n _A="$1"
    for _x in "${_A[@]}"; do
      [ "$_x" = "$2" ] && return 0
    done
    return 1
  }
  while read -p "choose an interface to configure for a static IP: " -r user_iface;
      ! contains interfaces "$user_iface"; do
    echo "$user_iface is not a valid interface!"
  done
  case $user_iface in
    None)
      echo "skipping static IP configuration"; return 0;;
  esac

  read -p "Enter the static IP address in the format xxx.xxx.xxx.xxx/yy: " IP
  read -p "enter static router address in the format xxx.xxx.xxx.xxx: " ROUTER
  read -p "enter the static DNS in the format xxx.xxx.xxx.xxx xxx.xxx.xxx.xxx: " DNS

  tmpFile=/tmp/static.ip
  echo "interface $user_iface" > $tmpFile
  echo "static ip_address=$IP" >> $tmpFile
  echo "static routers=$ROUTER" >> $tmpFile
  echo "static domain_name_servers=$DNS" >> $tmpFile


  cat $tmpFile | sudo tee -a /etc/dhcpcd.conf

  echo "Restart required for changes to take effect"
}
ch_passwd
install_pkgs
ssh_keys
dot_files
spi_setup
static_ip
host_name
