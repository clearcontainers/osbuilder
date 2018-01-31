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

# This scirpt creates a Clear Container image called container.img based
# on the rootfs directory.

set -e
if [ -n "$DEBUG" ] ; then
	set -x
fi

ROOTFS="$1"
SCRIPT_NAME="${0##*/}"

die()
{
	msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}

info()
{
	echo -e "\e[1mINFO\e[0m: $*"
}

warning()
{
	echo -e "\e[93mWARNING\e[0m: $*"
}

usage()
{
	cat <<EOT
Usage: ${SCRIPT_NAME} ROOTFS
	This script will create a Clear Container image file "container.img" based
	on the ROOTFS directory.
EOT
exit 1
}

[ -n "${ROOTFS}" ] || usage
[ "$(id -u)" -eq 0 ] || die "$0: must be run as root"
[ -d "${ROOTFS}" ] || die "${ROOTFS} is not a directory"

# In order to support memory hotplug, image must be aligned to 128M
MEM_BOUNDARY=128
# Image file to be created:
IMAGE="container.img"
# Image contents source folder
IMG_SIZE=${IMG_SIZE:-$MEM_BOUNDARY}
BLOCK_SIZE=${BLOCK_SIZE:-4096}

remaining=$(echo "$IMG_SIZE % $MEM_BOUNDARY" | bc)
if [ "$remaining" != "0" ];then
	 warning "image size '$IMG_SIZE' is not aligned to memory boundary '$MEM_BOUNDARY', aligning it"
	IMG_SIZE="$((IMG_SIZE + MEM_BOUNDARY - remaining))"
fi

info "Creating raw disk with size ${IMG_SIZE}M"
#Create image file
qemu-img create -f raw "${IMAGE}" "${IMG_SIZE}M"

# Only one partition is required for the image
#Create partition table
parted ${IMAGE} --script "mklabel gpt" \
"mkpart ext4 1M -1M"

# Get the loop device bound to the image file (requires /dev mounted in the
# image build system and root privileges)
DEVICE=$(losetup -P -f --show ${IMAGE})

#Refresh partition table
partprobe ${DEVICE}

mkdir -p ./img
mkfs.ext4 -F -b "${BLOCK_SIZE}" "${DEVICE}p1"
mount "${DEVICE}p1" ./img

# Copy content to image
cp -a "${ROOTFS}"/* ./img

sync
# Cleanup
umount -l ./img
fsck -D -y "${DEVICE}p1"
losetup -d "${DEVICE}"

echo "Image created"
