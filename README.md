# osbuilder - Clear Containers guest O/S building scripts

* [Overview](#overview)
* [Introduction](#introduction)
* [Building a guest image](#building-a-guest-image)
    * [Build a rootfs](#build-a-rootfs)
      * [(optional) Customise the rootfs](#(optional)-customise-the-rootfs)
      * [Create a rootfs image](#create-a-rootfs-image)
      * [Default packages](#default-packages)
        * [Clear Linux based packages security limitations](#clear-linux-based-packages-security-limitations)
* [Build guest kernel](#build-guest-kernel)
* [Using the newly generated custom rootfs and kernel images](#using-the-newly-generated-custom-rootfs-and-kernel-images)
    * [Clear Containers 3.x](#clear-containers-3.x)
        * [Installing the custom roots image](#installing-the-custom-roots-image)
        * [Installing the new kernel](#installing-the-new-kernel)
* [Dependencies](#dependencies)
* [Using osbuilder scripts with Docker*](#using-osbuilder-scripts-with-docker)
* [Limitations](#limitations)
* [Environment Variables](#environment-variables)


## Overview

The Clear Containers hypervisor creates a virtual machine (VM) in which to run
the workload. To do this, the hypervisor requires a root filesystem (rootfs) image
and a guest kernel image in order to create the guest environment in
which the container runs.

This repository contains scripts to create a custom
[root filesystem image](https://github.com/clearcontainers/runtime/blob/master/docs/architecture/architecture.md#root-filesystem-image) ("rootfs") and [guest kernel image](https://github.com/clearcontainers/runtime/blob/master/docs/architecture/architecture.md#guest-kernel). These custom resources may be used for testing and developing new features.

## Introduction

The scripts in this repository are called by running `make(1)` specifying
particular targets. The scripts use a work directory for storing all files. By
deafult this will be created automatically as `./workdir` however this can be
changed by setting the `WORKDIR` environment variable. See [Environment Variables](#environment-variables).

## Building a guest image

A guest image is a rootfs that has been converted into a disk image.

### Build a rootfs

The `rootfs` target will generate a directory called `workdir/rootfs`,
overwriting duplicate files:

```
$ sudo -E  make rootfs
```

#### (optional) Customise the rootfs

It is possible to customise the rootfs; simply modify the files below
`workdir/rootfs` as desired.

#### Create a rootfs image

The `image` target will create a disk image called `container.img` from the `workload/rootfs` directory. This image file is compatible with the official Clear Containers images provided with a Clear Containers installation.

Note:

The `image` target will not create or populate the `workdir/rootfs` directory
so it is necessary to [build a rootfs](#build-a-rootfs) first.

Use the `IMG_SIZE` environment variable to change the size of the image if
desired. See [Environment Variables](#environment-variables).

```
$ sudo -E make image
```

#### Default packages

By default, the rootfs image is based on
[Clear Linux for Intel\* Architecture](https://clearlinux.org), but the `workdir/rootfs` directory can be
populated with any other source.

Packages are installed inside the generated image. You can install extra
packages using the environment variable `EXTRA_PKGS`.
See [Environment Variables](#environment-variables).

- `cc-agent`
- cc-oci-runtime-extras
- [clear-containers-agent]
- coreutils-bin
- [hyperstart]
- iptables-bin
- [systemd]
- systemd-bootchart

##### Clear Linux based packages security limitations

Although the Clear Linux rootfs is constructed from `rpm` packages, Clear
Linux itself is not an `rpm`-based Linux distribution (the software installed
on a Clear Linux system is not managed using `rpm`).

The `rpm` packages used to generate the rootfs are not signed, so there is no
way to ensure that downloaded packages are trustworthy.

If you are willing to use Clear Linux based images, official Clear Containers
rootfs images can be obtained from https://download.clearlinux.org/releases.

## Build guest kernel

Clear Containers uses the [Linux* kernel](https://www.kernel.org).

To build a kernel compatible with Clear Containers using the make `kernel` target. This
will clone the [Clear Container Kernel] in the `workdir/linux` directory
(which will be created if necessary). On success two new kernel images will be created:
  - `workdir/vmlinuz.container` (compressed kernel image)
  - `workdir/vmlinux.container` (uncompressed kernel image)


```
$ # Pull and setup latest kernel for Clear Containers
$ sudo -E make kernel-src
$ sudo -E make kernel
```

## Using the newly generated custom rootfs and kernel images

### Clear Containers 3.x

This section covers using the new resources with `cc-runtime`.

#### Installing the custom roots image

1. Install the image file
   ```
   $ sudo install --owner root --group root --mode 0755 workdir/container.img /usr/share/clear-containers/
   ```

1. Update the runtime configuration for the image
   ```
   $ # (note that this is only an example using default paths).
   $ sudo sed -i.bak -e 's!^\(image = ".*"\)!# \1 image = "/usr/share/clear-containers/container.img"!g' /usr/share/defaults/clear-containers/configuration.toml
   ```

#### Installing the new kernel

1. Install the kernel image (run `make help` for more information)
   ```
   $ sudo make install-kernel
   ```

1. Verify kernel is configured
   ```
   $ cc-runtime cc-env
   ```

## Dependencies

In order to work the osbuilder scripts require the following programs:

- `bc`
- `dnf` or `yum`
- `gcc`
- `gdisk`
- `git`
- `make`
- `parted`
- `qemu-img`

To check if these tools are available locally, run:

```
$ make check-deps
```

## Using osbuilder scripts with Docker*

If you do not want to install all the dependencies on your system to run
the osbuilder scripts, you can instead run them under Docker. To run the
osbuilder scripts inside a Docker container the following requirements must be
met:

1. Docker 1.12+ installed
 
2. `runc` is configured as the default runtime

   To check if `runc` is the default runtime:

   ```
   $ docker info | grep 'Default Runtime: runc'
   ```

   Note

   This requirement is specifically for `docker build` which does not work
   with a hypervisor-based runtime currently (see issue
   [\#8](https://github.com/clearcontainers/osbuilder/issues/8)
   for more information.

3. Export `USE_DOCKER` variable

   ```
   $ export USE_DOCKER=true
   ```
4. Use osbuilder makefile targets as described in [Build guest image](#Build-guest-image)

   Example:
   ```
   $ export USE_DOCKER=true
   $ # Download Clear Containers guest base rootfs
   $ sudo -E make rootfs
   $ # Build an image with the conent generated by 'make rootfs'
   $ sudo -E image
   ```

## Limitations

Using `osbuilder` with ubuntu 14.06 fails because an old version of `rpm`.
However, it is still possible to [run the scripts using docker](#Using-osbuilder-scripts-with-docker).


## Environment Variables

Run `make help` to see a list of supported environment variables that can be
used to change the tools behaviour.

[systemd]: <https://www.freedesktop.org/wiki/Software/systemd/>

[hyperstart]: <https://github.com/clearcontainers/hyperstart>

[clear-containers-agent]: <https://github.com/clearcontainers/agent>

[Clear Container Kernel]: <https://github.com/clearcontainers/linux>
