#!/bin/bash
#
#  Copyright (C) 2017 Intel Corporation
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

set -e
set -x

SCRIPT_NAME="${0##*/}"
DNF_CONF="/etc/dnf/clear-dnf.conf"

BUILD="$1"
ROOTFS_DIR="$(pwd)/rootfs"

die()
{
	msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}

info()
{
	msg="$*"
	echo "INFO: ${msg}" >&2
}

usage()
{
	cat <<EOT
Usage: ${SCRIPT_NAME} rootfs|kernel|image
rootfs : Build a rootfs based on Clear Linux packages
kernel : Build a kernel for clear containers
image  : Build a Clear Containers image based on rootfs directory
EOT
	exit 1
} 

build_rootfs()
{
    mkdir -p "${ROOTFS_DIR}"
    DNF="dnf --config=$DNF_CONF -y --installroot=${ROOTFS_DIR} --noplugins"
	$DNF install systemd hyperstart cc-oci-runtime-extras coreutils systemd-bootchart
}

build_kernel()
{
	pushd linux
	make -j$(nproc)
	popd
	cp linux/vmlinux vmlinux.container
}

# main
[ -n "${BUILD}" ] || usage


case "$BUILD" in
        rootfs)
			build_rootfs
            ;;
         
        kernel)
			build_kernel
            ;;
         
        image)
			image_builder.sh "$(pwd)/rootfs"
            ;;
        *)
			usage
esac
