#!/bin/sh
# Functions to run or stop quickly an LXD container
# and mount it on host folder with clean rules

if ! type complete &>/dev/null; then
    autoload bashcompinit
    bashcompinit
fi

PATH_SCRIPT=$(dirname ${BASH_SOURCE[0]-$0})
PATH_SCRIPT=$(cd $PATH_SCRIPT && pwd)

. ${PATH_SCRIPT}/config.sh

# POSIX confirm
_confirm() {
	echo -n $1 " ? [y/n]"
	old_stty_cfg=$(stty -g)
	stty raw -echo
	answer=$( while ! head -c 1 | grep -i '[ny]' ;do true ;done )
	stty $old_stty_cfg
	echo
	if echo "$answer" | grep -iq "^y" ;then
	    ${@:2} && return 0
	fi
        return 1
}

# Get the UID and the GID of the current user in the container (or root by default)
_getUidGidLxd() {
    if [ -d "$LXD_SOURCE_DIR/$1/rootfs/home/$1" ]; then
        echo "The user $1 was found and will be used to make the uig/gid mapping."
        UID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/home/$1 | awk '{print $3}'`
        GID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/home/$1 | awk '{print $4}'`
    elif [ -d "$LXD_SOURCE_DIR/$1/rootfs/home/ubuntu" ]; then
        echo "The user ubuntu was found and will be used to make the uig/gid mapping."
        UID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/home/ubuntu | awk '{print $3}'`
        GID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/home/ubuntu | awk '{print $4}'`
    else
        echo "No unprivileged user was found, therefore the mapping will use the root user."
        UID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/root | awk '{print $3}'`
        GID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/root | awk '{print $4}'`
    fi
}

# Umount with bindfs a container 
lxd-bindfs-umount() {
    if [ -z "$1" ]; then
        echo "lxd-bindfs-umount <container name>"
    elif [ "$(ls -A ${LXD_MOUNT_DIR}/$1 )" ]; then
        sudo umount ${LXD_MOUNT_DIR}/$1 && echo "Umount done (in ${LXD_MOUNT_DIR}/$1)"
    fi
}

# Mount with bindfs a container 
lxd-bindfs-mount() {
    if [ $# -ne 5 ]; then
        echo "lxd-bindfs-mount <container name> <host user> <host group> <guest user> <guest group>"
    elif [ "$(ls -A ${LXD_MOUNT_DIR}/$1 )" ]; then
        echo "The mount directory is not empty : $LXD_MOUNT_DIR/$1"
        echo "Already mounted ?"
    else
        sudo bindfs --force-user=$2 --force-group=$3 --create-for-user=$4 --create-for-group=$5 ${LXD_SOURCE_DIR}/$1/rootfs ${LXD_MOUNT_DIR}/$1 && echo "Mount done (in ${LXD_MOUNT_DIR}/$1)"
    fi
}

# Start a container and mount it
lxd-stop() {
    if [ -z "$1" ]; then
        echo "lxd-stop <container name>"
    else
        if [ `lxc list --columns=n ^${1}$ | wc -l` -eq 5 ]; then
        	if [ `lxc info $1 | egrep -i "^Status: " | cut -d" " -f2` == 'Running' ]; then
            		if lxc stop $1 --timeout 30; then
                		echo "LXD $1 stopped"
            		else
                		lxc stop $1 --force && echo "LXD $1 stopped, but forced!"
            		fi
        	fi

        	if [ "$(ls -A ${LXD_MOUNT_DIR}/$1 )" ]; then
            		lxd-bindfs-umount $1
        	fi
         else
                 echo "No container named $1 found"
         fi
    fi
}

# Stop a container and umount it
lxd-start() {
    if [ -z "$1" ]; then
        echo "lxd-start <container name>"
    else
        if [ `lxc list --columns=n ^${1}$ | wc -l` -eq 5 ]; then
        	if [ `lxc info $1 | egrep -i "^Status: " | cut -d" " -f2` == "Stopped" ]; then
            		lxc start $1 && echo "LXD $1 started"
        	fi
        	MOUNT_RESULT=0
        	if [ ! -d "${LXD_MOUNT_DIR}/$1" ]; then
            		echo "No destination directory to mount the container : ${LXD_MOUNT_DIR}/$1"
	    		_confirm "Do you wish to create this directory" sudo mkdir -p ${LXD_MOUNT_DIR}/$1
            		MOUNT_RESULT=$?
        	fi
        	if [ ${MOUNT_RESULT} -eq 0 ]; then
			_getUidGidLxd $1 && lxd-bindfs-mount $1 ${USER_HOST_MOUNT} ${GROUP_HOST_MOUNT} ${UID_GUEST_MOUNT} ${GID_GUEST_MOUNT}
		fi
	else
		echo "No container named $1 found"
	fi
    fi
}

# Create the default LXD container with a current user
lxd-create() {
    if [ $# -ne 2 ]; then
        echo "lxd-create <image name> <container name>"
        echo "To get the list of images availables : lxc image list <remote>"
    else
        read -p "Do you wish to create the new container named $2 with the image $1 ? [Y/n] " yn
        case ${yn} in
            [Yy]* )
                lxc launch $1 $2 && lxc exec $2 -- /usr/sbin/useradd $2 && lxc exec $2 -- /usr/sbin/passwd $2 && lxd-start $2 ;;
            * )
                return ;;
        esac
    fi
}

_lxdListComplete()
{
    if [ -d "${LXD_SOURCE_DIR}" ] && [ -x "${LXD_SOURCE_DIR}" ]; then
        local cur=${COMP_WORDS[COMP_CWORD]}
        COMPREPLY=( $(compgen -W "$(cd ${LXD_SOURCE_DIR} && ls -d */ 2>/dev/null | tr '/\n' ' ' && printf '\n' )" -- ${cur}) )
    fi
}
_mountLxdListComplete()
{
    if [ -d "${LXD_MOUNT_DIR}" ] && [ -x "${LXD_MOUNT_DIR}" ]; then
        local cur=${COMP_WORDS[COMP_CWORD]}
        COMPREPLY=( $(compgen -W "$(cd ${LXD_MOUNT_DIR} && ls -d */ 2>/dev/null | tr '/\n' ' ' && printf '\n' )" -- ${cur}) )
    fi

}
complete -F _lxdListComplete lxd-start
complete -F _lxdListComplete lxd-stop
complete -F _lxdListComplete lxd-bindfs-mount
complete -F _lxdListComplete lxd-bindfs-umount
