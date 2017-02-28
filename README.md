# osbuilder

Clear Containers guest OS building scripts

## Build guest image ##

### Build a base rootfs ###
The "rootfs" target will generate a directory
called "workdir/rootfs".

```
sudo -E  make rootfs
```

### (optional) customize clear container rootfs ###
After generate a initial rootfs (previous step) you can 
customize it by adding anything you need to rootfs 
directory.

### Create Clear Container image ###
The "image" target will take the "workload/rootfs" directory
and will generate a guest image named container.img in the workdir
directory compatible with Clear Containers.

```
sudo -E make image
```

### Default packages ###
By default, the rootfs for the Clear Containers image is based on
Clear Linux for Intel\* Architecture, but WORKLOAD/rootfs could be
populated with any other source.

The required packages are:

- [systemd]
- [hyperstart]
- cc-oci-runtime boot service [cc-agent service]
- cc-oci-runtime boot target [cc-agent target]

#### Clear Linux based packages security limitations  ####

Clear Linux is not an rpm-based Linux distribution and
the rpm packages are not signed, so there is no way
to ensure that downloaded packages are trustworthy.

If you are willing to use Clear Linux based images, we encourage you
to use the Clear Containers images provided from its website
https://download.clearlinux.org/current/.

## Build guest kernel ##

Clear Containers uses the Linux kernel, you can build a
kernel compatible with Clear Containers using the make
"kernel" target. This will clone the [Clear Container Kernel]
if the directory "workdir/linux" does not exist, then will build it.
On success the new kernel will be located in
workdir/vmlinux.container


```
sudo -E make kernel
```

## Use new generated kernel and image with cc-oci-runtime ##

To use the new generated kernel or image copy the defaults file:

```
sudo mkdir -p /etc/cc-oci-runtime
sudo cp /usr/share/defaults/cc-oci-runtime/vm.json /etc/cc-oci-runtime/vm.json
```

And modify the paths for your new kernel and image:

```
{
	"vm": {
		"path": "QEMU PATH...",
		"image": "FULL IMAGE NAME ",
		"kernel": {
			"path": "FULL KERNEL NAME",
			"parameters": "CMDLINE .."
		}
	}
}
```


[systemd]: <https://www.freedesktop.org/wiki/Software/systemd/>

[hyperstart]: <https://github.com/clearcontainers/hyperstart>

[cc-agent target]: <https://github.com/01org/cc-oci-runtime/blob/master/data/cc-agent.target>

[cc-agent service]: <https://github.com/01org/cc-oci-runtime/blob/master/data/cc-agent.service>

[Clear Container Kernel]: <https://github.com/clearcontainers/linux>
