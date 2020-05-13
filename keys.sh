#!/bin/bash
sshkey_repo_name="txoof/ssh_keys"

sshkey_repo="git@github.com:$sshkey_repo_name.git"
sshkey_link="https://github.com/$sshkey_repo_name/settings/keys"

ssh_keys () {
        echo " "
        echo "Checking ssh keys"
        if [ ! -f ~/.ssh/id_rsa ]; then
          ssh-keygen -f ~/.ssh/id_rsa
        fi

        echo "Add this key as a read-only deploy key at the following link:
        $sshkey_link"

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

ssh_keys
