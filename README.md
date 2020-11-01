# lxd-functions

This bash file allows you to create, start and delete an LXD container.
The goal is to mount the container with appropriate rights and ownership (with bindfs).
After that the container is started, you can work directly on the host machine, your user is used in the mounted point, and you have full access to it. In the container, a default user is used to map with the host user.

## Dependencies

  * `bindfs`: the bash package to make advanced mounted directory (in ubuntu `sudo apt-get install bindfs`)
  * `sudo`: required to get root privileges for mounting the container or creating missing destination directory

## Installation

Clone this repository in `/path/to/lxd-functions`

Add in the `.bashrc` file (`/home/<me>/.bashrc`) or in the `.profile` :

```
if [ -f /path/to/lxd-functions/main.sh ]; then
  . /path/to/lxd-functions/main.sh
fi
```

Copy the example of configration file `/path/to/lxd-functions/config.sh.example` to `/path/to/lxd-functions/config.sh` and edit it, specially check that :

 * `LXD_SOURCE_DIR` need to match with the path of LXD containers in your system
 * `LXD_MOUNT_DIR` it's where containers will be mounted. The default value is `/var/lxd`. It will be automatically created if you run the script.

To allow bash-completion to work, you need to give read access of the `LXD_SOURCE_DIR`. To automatically add read access, run the following command: `lxd-bash-completion`

**No need to change an existing LXD container, this script use the LXD API without container modification !**

## Commands

Commands available:

  * `lxd-start <container name>` <container name> (Start an LXD container and mount it)
  * `lxd-stop <container name>` (Stop an LXD container and umount it)
  * `lxd-bindfs-mount <container name> <host user> <host group> <guest user> <guest group>` (Mount an LXD Container)
  * `lxd-bindfs-umount <container name>` (Umount an LXD Container)
  * More soon (for example `lxd-create` ...)

## Example of use

In this example, you already have a LXD named `mylxd` (started or not, it doesn't matter) and you let the default configuration (in the `config.sh`).
Before working with it, just enter this : `lxd-start mylxd`
The script will start LXD container (with `lxc start mylxd`), then try to mount the container in this path : `/var/lxd/mylxd`, if the directory `mylxd` isn't already present, the script will ask if you agree to create it automatically.
That's all ! You can try to create files directly in the container or in the mounted directory, the file created will have the current user uid/gid in the host and the default user in the container.

The command `lxd-stop mylxd` is not required, but it will shutdown the lxd and unmount it for you.

Others commands are not needed too, this is for advanced use.

## Questions ? Want to involve ?

Just ask in the issue section if it's not already done ;)
