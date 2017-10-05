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
if [ -n "$DEBUG" ] ; then
	set -x
fi


SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(dirname $(realpath -s $0))"
REPO_URL=${REPO_URL:-https://download.clearlinux.org/current/x86_64/os/}
EXTRA_PKGS=${EXTRA_PKGS:-""}


IMAGE_BUILDER_SH="image_builder.sh"
if ! type ${IMAGE_BUILDER_SH} >/dev/null 2>&1; then
	IMAGE_BUILDER_SH="${SCRIPT_DIR}/${IMAGE_BUILDER_SH}"
fi

KERNEL_BUILDER_SH="kernel_builder.sh"
if ! type ${KERNEL_BUILDER_SH} >/dev/null 2>&1; then
	KERNEL_BUILDER_SH="${SCRIPT_DIR}/${KERNEL_BUILDER_SH}"
fi

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
Usage: ${SCRIPT_NAME} [options] <rootfs|kernel|image>
rootfs     : Build a rootfs based on Clear Linux packages
kernel-src : Pull latest kernel source for clear containers
kernel     : Build a kernel for clear containers
image      : Build a Clear Containers image based on rootfs directory

Options:
-k <kernel-repo>: Git repository to pull linux source
-t <kernel-tag> : Clear Containers kernel tag to pull
-h              : Show this help
EOT
	exit 1
} 

check_program(){
	type "$1" >/dev/null 2>&1
}

generate_dnf_config()
{
	cat > "${DNF_CONF}" << EOF
[main]
cachedir=/var/cache/dnf/clear/
keepcache=0
debuglevel=2
logfile=/var/log/dnf.log
exactarch=1
obsoletes=1
gpgcheck=0
plugins=0
installonly_limit=3
#Dont use the default dnf reposdir
#this will prevent to use host repositories
reposdir=/root/mash

[clear]
name=Clear
failovermethod=priority
baseurl=${REPO_URL}
enabled=1
gpgcheck=0
EOF
}

build_rootfs()
{
	if [ ! -f "${DNF_CONF}" ]; then
		DNF_CONF="./clear-dnf.conf"
		generate_dnf_config
	fi
	mkdir -p "${ROOTFS_DIR}"
	if [ -n "${PKG_MANAGER}" ]; then
		info "DNF path provided by user: ${PKG_MANAGER}"
	elif check_program "dnf"; then
		PKG_MANAGER="dnf"
	elif check_program "yum" ; then
		PKG_MANAGER="yum"
	else
		die "neither yum nor dnf is installed"
	fi

	info "Using : ${PKG_MANAGER} to pull packages from ${REPO_URL}"

	DNF="${PKG_MANAGER} --config=$DNF_CONF -y --installroot=${ROOTFS_DIR} --noplugins"
	$DNF install systemd hyperstart cc-oci-runtime-extras coreutils-bin \
		systemd-bootchart iptables-bin clear-containers-agent ${EXTRA_PKGS}
	[ -n "${ROOTFS_DIR}" ]  && rm -r "${ROOTFS_DIR}/var/cache/dnf"
}


check_root()
{
	if [ "$(id -u)" != "0" ]; then
		echo "Root is needed"
		exit 1
	fi
}

while getopts hk:t: opt
do
	case $opt in
		h)	usage ;;
		k)	KERNEL_BUILDER_SH="$KERNEL_BUILDER_SH -k ${OPTARG}" ;;
		t)	KERNEL_BUILDER_SH="$KERNEL_BUILDER_SH -t ${OPTARG}" ;;
	esac
done

shift $(($OPTIND - 1))

# main
BUILD="$1"
[ -n "${BUILD}" ] || usage


case "$BUILD" in
        rootfs)
			check_root
			build_rootfs
            ;;

        kernel-src)
			$KERNEL_BUILDER_SH prepare
            ;;
         
        kernel)
			$KERNEL_BUILDER_SH build
			rm -f vmlinux.container
			rm -f vmlinuz.container
			cp linux/vmlinux vmlinux.container
			cp linux/arch/x86/boot/bzImage vmlinuz.container
			info "vmlinux kernel ready in vmlinux.container"
			info "vmlinuz kernel ready in vmlinuz.container"
            ;;
         
        image)
			check_root
			$IMAGE_BUILDER_SH "$(pwd)/rootfs"
            ;;
        *)
			usage
esac
