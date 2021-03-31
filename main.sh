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

_checkRights() {
    if [ "$EUID" -eq 0 ]
        then echo "Please run this function without root privileges. The sudo command will be used when required root access. The LXD API need to be run with your current user." >&2
        return 1
    fi
    if ! command -v sudo &> /dev/null ; then
        echo "The sudo command is missing, and this is a required dependency for accessing root privileges when needed." >&2
        return 1
    fi
    return 0
}

_checkBindfs() {
    if ! command -v bindfs &> /dev/null ; then
        echo "The bindfs command is missing, and this is a required dependency for mounting the container." >&2
        echo "You can install this dependency on ubuntu/debian like this: sudo apt-get install bindfs" >&2
        return 1
    fi
    return 0
}

# Get the UID and the GID of the current user in the container (or root by default)
_getUidGidLxd() {
    if [ -d "${LXD_SOURCE_DIR}/$1" ] && [ ! -x "${LXD_SOURCE_DIR}/$1" ]; then
        if [ "${ASK_CHANGE_CONTAINER_RIGHTS}" = "true" ]; then
            echo "The container path is not accessible (this is normal, if LXD is installed via snap): ${LXD_SOURCE_DIR}/$1"
            _confirm "Do you wish to add access right (x) this directory (required to proceed)" sudo chmod go+x ${LXD_SOURCE_DIR}/$1
        else
          echo "Give access to container path: ${LXD_SOURCE_DIR}/$1"
          sudo chmod go+x ${LXD_SOURCE_DIR}/$1
        fi
    fi

    if [ -d "${LXD_SOURCE_DIR}/$1/rootfs" ] && [ -x "${LXD_SOURCE_DIR}/$1/rootfs" ]; then
        DEFAULT_USER="root"
        for mappingUser in "${MAPPING_USERS[@]}"; do
            if [ "${mappingUser}" = "CONTAINER" ] && [ -d "${LXD_SOURCE_DIR}/$1/rootfs/home/$1" ]; then
                DEFAULT_USER=$1
                break
            elif [ -d "${LXD_SOURCE_DIR}/$1/rootfs/home/${mappingUser}" ]; then
                DEFAULT_USER=$mappingUser
                break
            fi
        done
        MAPPING_USER=$DEFAULT_USER

        if [ "${ASK_MAPPING_USER}" = "true" ]; then
            echo -n "User in container to make uig/gid mapping [${DEFAULT_USER}]: "
            read INPUT_USER
            if [ "$INPUT_USER" = "" ]; then
                INPUT_USER=$DEFAULT_USER
            fi
            MAPPING_USER=$INPUT_USER
        fi

        if [ "${MAPPING_USER}" != 'root' ] && [ -d "${LXD_SOURCE_DIR}/$1/rootfs/home/${MAPPING_USER}" ]; then
            echo "The user $MAPPING_USER was found and will be used to make the uig/gid mapping."
            UID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/home/${MAPPING_USER} | awk '{print $3}'`
            GID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/home/${MAPPING_USER} | awk '{print $4}'`
        elif [ "${MAPPING_USER}" = 'root' ] && [ -d "${LXD_SOURCE_DIR}/$1/rootfs/root" ]; then
            echo "The root user will bed used to make the uig/gid mapping."
            UID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/root | awk '{print $3}'`
            GID_GUEST_MOUNT=`ls -ldn ${LXD_SOURCE_DIR}/$1/rootfs/root | awk '{print $4}'`
        else
            echo "Unable found the user $MAPPING_USER in the container"
            return 1
        fi
        return 0
    else
        echo "Unable to access to the rootfs of the container: ${LXD_SOURCE_DIR}/$1/rootfs" >&2
        return 1
    fi
}

# Umount a container
lxd-bindfs-umount() {
    _checkRights || return 1
    if [ -z "$1" ]; then
        echo "lxd-bindfs-umount <container name>" >&2
    elif [ -d "${LXD_MOUNT_DIR}/$1" ] && [ -x "${LXD_MOUNT_DIR}/$1" ] && [ "$(ls -A ${LXD_MOUNT_DIR}/$1 )" ]; then
        sudo umount ${LXD_MOUNT_DIR}/$1 && echo "Umount done (in ${LXD_MOUNT_DIR}/$1)"
    fi
}

# Mount with bindfs a container 
lxd-bindfs-mount() {
    _checkRights || return 1
    _checkBindfs || return 1
    if [ $# -ne 5 ]; then
        echo "lxd-bindfs-mount <container name> <host user> <host group> <guest user> <guest group>"
    elif [ ! -d "${LXD_MOUNT_DIR}/$1" ] || [ ! -x "${LXD_MOUNT_DIR}/$1" ]; then
        echo "Unable to access to the directory: ${LXD_MOUNT_DIR}/$1" >&2
        echo "Directory exist ?" >&2
    elif [ "$(ls -A ${LXD_MOUNT_DIR}/$1 )" ]; then
        echo "The mount directory is not empty : $LXD_MOUNT_DIR/$1" >&2
        echo "Already mounted ?" >&2
    else
        sudo bindfs --force-user=$2 --force-group=$3 --create-for-user=$4 --create-for-group=$5 ${LXD_SOURCE_DIR}/$1/rootfs ${LXD_MOUNT_DIR}/$1 && echo "Mount done (in ${LXD_MOUNT_DIR}/$1)"
    fi
}

# Stop a container and umount it
lxd-stop() {
    _checkRights || return 1
    if [ -z "$1" ]; then
        echo "lxd-stop <container name>" >&2
    else
        if [ `lxc list --columns=n ^${1}$ | wc -l` -eq 5 ]; then
            if [ `lxc list --columns=s ^${1}$ | grep RUNNING | wc -l` -eq 1 ]; then
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
            echo "No container named $1 found" >&2
         fi
    fi
}

# Start a container and mount it
lxd-start() {
    _checkRights || return 1
    if [ -z "$1" ]; then
        echo "lxd-start <container name>" >&2
    else
        if [ `lxc list --columns=n ^${1}$ | wc -l` -eq 5 ]; then
            if [ `lxc list --columns=s ^${1}$ | grep STOPPED | wc -l` -eq 1 ]; then
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
            else
              echo "Unable to mount the container, the destination directory is missing" >&2
            fi
        else
            echo "No container named $1 found" >&2
        fi
    fi
}

# Create the default LXD container with a current user
lxd-create() {
    _checkRights || return 1
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

_lxdListComplete() {
   local cur opts prev
   cur="${COMP_WORDS[COMP_CWORD]}"
   prev="${COMP_WORDS[COMP_CWORD-1]}"
   opts="$(lxc list --format=csv --columns=n)"
   if [ "${prev}" == "lxd-start" ] || [ "${prev}" == "lxd-bindfs-mount" ]; then
       COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
   fi
}

_mountedLxdListComplete() {
    if [ -d "${LXD_MOUNT_DIR}" ] && [ -x "${LXD_MOUNT_DIR}" ]; then
        local cur opts prev
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        cur="${COMP_WORDS[COMP_CWORD]}"
        opts="$(find ${LXD_MOUNT_DIR} -mindepth 1 -maxdepth 1 -not -empty -type d -print0 | xargs -r -0 -n 1 basename)"
        if [ "${prev}" == "lxd-stop" ] || [ "${prev}" == "lxd-bindfs-umount" ]; then
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        fi
    fi
}
complete -F _lxdListComplete lxd-start
complete -F _mountedLxdListComplete lxd-stop
complete -F _lxdListComplete lxd-bindfs-mount
complete -F _mountedLxdListComplete lxd-bindfs-umount
