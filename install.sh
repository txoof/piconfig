#!/bin/bash

# list of packages that should be installed immediately
packages=( git vim python3 python3-pip tmux)

# keys are stored one per file in the format `idrsa_user@host_YYYY.MM.DD`
sshkey_repo="git@github.com:txoof/ssh_keys.git"

# dotfiles are stored here
dotfile_repo="git@github.com:txoof/Dotfiles.git"

# this appears to be important for dtparam -- enabling spi
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf


# change the default password
ch_password () {
	echo " "
	echo "Setting password for user $USER"
	echo "setting password..."
	passwd
	echo " "
}

# install packages
install_pkgs () {
  CONTINUE="True"
  echo " "
  echo "preparing to install debian packages"
  while [ "$CONTINUE" == "True" ]; do
    echo "debian packages to install:"
    printf '%s\n' "${packages[@]}"

    echo " "
    echo "Add packages by typing the package name; remove packages with '-name'"
    echo "Type '*Done' to begin installing packages"
    read -p "Package name: " package

    if [ "$package" == "*Done" ]; then
      CONTINUE="False"
    else
      if [[ ${package:0:1} == "-" ]] ; then
	package=${package#?}
	for i in "${!packages[@]}"; do
	  if [[ ${packages[i]} = $package ]]; then
	    unset 'packages[i]'
	  fi
	done

      else
	packages+=( $package )
      fi
    fi

  done
  
  printf -v install '%s ' "${packages[@]}"
  echo " "
  echo "updating packages and installing packages"
  sudo apt-get update
  sudo apt-get ---with-new-pkgs --assume-yes upgrade
  sudo apt-get --assume-yes install $install
  
  echo " "
}

# set the hostname
host_name () {
	echo " "
	CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
	echo "Current hostname: $CURRENT_HOSTNAME"
	echo "Would you like to change this devices hostname?"
	read -p "Please enter a new hostname or press enter to skip: " NEW_HOSTNAME
	if [[ $NEW_HOSTNAME ]]; then
		echo $NEW_HOSTNAME | sudo tee /etc/hostname
		sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
		read -t 10 -p "Reboot in 10 Seconds N/y: " REBOOT
		case $REBOOT in
			[yY]* ) sudo shutdown -r now;;
			[nN]* ) echo "please reboot for hostname changes to take effect";;
		esac
        else
          echo "hostname unchanged"
	  echo " "
          return 0
	fi
}

# pull the ssh keys from the github repo and build the autorized_keys file
ssh_keys () {
	echo " "
	echo "Checking ssh keys"
	if [ ! -f ~/.ssh/id_rsa ]; then
	  ssh-keygen -f ~/.ssh/id_rsa
	fi
	
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

# function for checking input
# usage: contains array variable
contains () {
  typeset _x;
  typeset -n _A="$1"
  for _x in "${_A[@]}"; do
    [ "$_x" = "$2" ] && return 0
  done
  return 1
}


static_ip () {
  interfaces=()
  echo "Configuring static IP"
  echo "Choose an interface to configure -- enter 'None' to skip"
  # list all the available interfaces
  for iface in $(ifconfig | cut -d ' ' -f1 | tr ':' '\n'|awk NF)
  do
    printf "$iface\n"
    interfaces+=("$iface")
  done
  # add 'None' as an option in the list
  iface="None"
  printf "$iface\n"
  interfaces+=("$iface")



  # loop until user enters a valid interface from the list
  echo ${interfaces}
  echo " "
  while read -p "Interface: " -r user_iface;
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

  echo "current /etc/dhcpcd.conf"
  echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  cat /etc/dhcpcd.conf

  echo "appending dhcpcd.conf"
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  cat $tmpFile

  echo " "
  read -p "Continue with replacement? [Y/n]: " REPLACE
  case $REPLACE in
    [nN]*) echo "skipping..."; return 0;;
    [yY]*) echo "replacing here" cat $tmpFile | sudo tee -a /etc/dhcpcd.conf;;
        *) echo "skipping..."; return 0;;
  esac


  echo "Restart required for changes to take effect"
}


locale () {
  sudo dpkg-reconfigure tzdata

}

ch_password
locale
install_pkgs
ssh_keys
dot_files
spi_setup
static_ip
host_name
