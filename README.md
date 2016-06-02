# lxd-functions

This bash file allows you to create, start and delete an LXD container.
The goal is to mount the container with appropriate rights and ownership (with bindfs).
After container started, you can work directly on the host machine, the current user is used in the mounted point and you have full access to it. In the container, a default user is used to map with the host user.

## Dependencies

  * `bindfs` : the bash package to make advanced mounted directory (in ubuntu `sudo apt-get install bindfs`)

## Installation

Clone this repository in `/path/to/lxd-functions`

Add in the `.bashrc` file or `.profile` :

```
if [ -f /path/to/lxd-functions/main.sh ]; then
  . /path/to/lxd-functions/main.sh
fi
```

Edit the configuration file `/path/to/lxd-functions/config.sh`

To allow bash-completion to work, you need to give read access of the `/var/lib/lxd/containers` like this : `sudo chmod ugo+r /var/lib/lxd/containers/`

## Commands

Commands available:

  * `lxd-start` <container name> (Start an LXD container and mount it)
  * `lxd-stop <container name>` (Stop an LXD container and umount it)
  * `lxd-bindfs-mount <container name> <host user> <host group> <guest user> <guest group>` (Mount an LXD Container)
  * `lxd-bindfs-umount <container name>` (Umount an LXD Container)
