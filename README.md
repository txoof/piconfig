PiConfig
========
One-shot configuration of raspberry pi through a bash script. PiConfig makes it trivial to setup a new pi with a basic configuration. 

**Note** several of the repos are hard-coded into the script. If you wish to use this for your own configurations, fork the repo and change the following values:
`packages=()` Set your own packages
`sshkey_repo=""` Set yourown SSH public key repo
`dotfile_repo=""` Set your own [DotFiles](https://pypi.org/project/dotfiles/) repo

## Use
* make sure you have created `/boot/ssh` to enable ssh
* optionally [configure WiFi](https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md) in `/boot/wpa_supplicant.conf`

SSH to new pi `ssh pi@raspberrypi.local`

Copy and paste the following line on the prompt
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/txoof/piconfig/master/install.sh)"`

## Opperation
PiConfig does the following on execution:
* Prompts to change the default password
* Prompts to change the local timezone
* Updates the dpkg database prompts to add extra packages, installs default list (stored in `$packages`)
* Creates an SSH `id_rsa` keypair if it is missing and adds keys to `authorized_hosts` file
   * Prompts to add Key to github for cloning repos using SSH
   * Downloads SSH public keys from a repo (stored in `$sshkey_repo`) and adds to `~/.ssh/authorized_keys` -- see notes below for format of repo
* Clones a [Dotfiles](https://pypi.org/project/dotfiles/) repo (stored in `$dotfile_repo`)
   * Attempts to link `dotfilerc` -> `.dotfilerc`
   * Attempts to sync dotfiles
* Enables SPI interface
* Prompts to setup static IP for a single interface
* Prompts to set hostname

## Git Repos
### SSH Key Repo
`$sshkey_repo` -- PiConfig will attempt to download any public SSH keys stored in a remote repo and add them to `~/.ssh/authorized_keys`

**PUBLIC** SSH keys should be stored, one key per file in a repo in the following format:
* `idrsa_user@hostname_YYY.MM.DD` --> `idrsa_txoof@txoofs-computer.local_2019.07.23`

**NEVER STORE PRIVATE KEYS ON GITHUB**

### DotFiles Repo
`$dotfile_repo` -- PiConfig will attempt to clone the dot file repo and properly symlink them
DotFiles is a python script that helps keep dot rc files such as `.bashrc` or `.vimrc` in sync with a git repo.

DotFile repos are typically stored in ~/Dotfiles; the `dotfiles` executable then symlinks files as needed into `~/` 
