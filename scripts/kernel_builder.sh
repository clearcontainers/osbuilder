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

kernel_repo="https://github.com/clearcontainers/linux.git"
tag_version=""
cc_defconfig="arch/x86/configs/clear_containers_defconfig"

kernel_path=$(pwd)/linux

die() {
	echo >&2 -e "\e[1mERROR\e[0m: $*"
	exit 1
}

info() {
	echo -e "\e[1mINFO\e[0m: $*"
}

usage() { 
	cat << EOT
Usage: $0 [options] <subcommand>
Options:
-h            : show this help
-k <git-repo> : git repository to pull linux kernel
-t <tag>      : repository tag to checkout

Subcommands:
prepare : clone linux source code and patch it with clear-containers configuration
build   : build a kernel configured by prepare subcommand
EOT
	exit 1; 
}                                                                                                 

get_last_version() {
	#Clear Containers kernel release is tagged with \-\d+.container and is incremental
	local cc_release
	cc_release=$(git ls-remote --tags 2>/dev/null \
		| grep -oP '\-\d+\.container'  \
		| grep -oP '\d+' \
		| sort -n | \
		tail -1 )

	local tag
	tag=$(git ls-remote --tags 2>/dev/null \
		| grep -oP "v\d+\.\d+\.\d+\-${cc_release}.container" \
		| tail -1)

	echo "${tag}"
}

prepare_kernel(){
	#--depth n to not pull all the kernel
	if [ ! -d "$kernel_path" ]; then
		git clone --depth 1 "${kernel_repo}" "${kernel_path}"
	fi
	pushd "$kernel_path"
		git remote set-branches origin '*'
		if [ -z "${tag_version}" ] ; then
			tag_version=$(get_last_version)
		fi

		current_branch="$(git symbolic-ref HEAD 2>/dev/null)"
		current_branch=${current_branch##refs/heads/}

		info "fetch version ${tag_version}"
		git fetch origin tag "${tag_version}" --depth 1 || die "failed to fetch changes from ${tag_version} tag"

		info "check current branch contains tag ${tag_version}"
		git branch -q --contains "${tag_version}" "${current_branch}" | grep -P "^(\*\s)?${current_branch}$" \
			&& info "Current branch already contains ${tag_version}" && return

		info "deleting old backup branch linux-container-old"
		git branch -D linux-container-old || true

		info "Moving linux-container branch to linux-container-old"
		git branch -m linux-container linux-container-old || true

		info "Creating branch linux-container branch"
		git checkout -b linux-container "${tag_version}" || die "failed to create branch linux-container"
		make clear_containers_defconfig

	popd
}

build_kernel(){
	[ -d "${kernel_path}" ] || die "${kernel_path} repository not found, use run $0 prepare"
	pushd "${kernel_path}"
	make -j"$(nproc)" || die "failed to build vmlinux"
		[ -f "${kernel_path}/vmlinux" ] || die "failed to generate vmlinux"
	popd
}

while getopts hk:t: opt
do
	case $opt in
		h)	usage ;;
		k)	kernel_repo="${OPTARG}" ;;
		t)	tag_version="${OPTARG}" ;;
	esac
done

shift $(($OPTIND - 1))
SUBCOMMAND=$1

case "$SUBCOMMAND" in
	prepare)
		prepare_kernel "$@"                                                                        
		kernel_config="${kernel_path}/.config"
		info "Using clear containers config:"
		info "${kernel_config}"
		info "kernel sources ready in ${kernel_path}"
		;;
	build)
		build_kernel "$@"                                                                        
		;;
	*)
		usage
		exit 1
		;;
esac

