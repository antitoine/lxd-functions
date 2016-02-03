# lxd-functions

## Installation

Clone this repository in `/path/to/lxd-functions`

Add in the `.bashrc` file or `.profile` :

```
if [ -f /path/to/lxd-functions/main.sh ]; then
  . /path/to/lxd-functions/main.sh
fi
```

Edit the configuration file `/path/to/lxd-functions/config.sh`

## Commands

Commands available:

  * `lxd-start` <container name> (Start an LXD container and mount it)
  * `lxd-stop <container name>` (Stop an LXD container and umount it)
  * `lxd-bindfs-mount <container name> <host user> <host group> <guest user> <guest group>` (Mount an LXD Container)
  * `lxd-bindfs-umount <container name>` (Umount an LXD Container)