#!/bin/bash
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

script_dir=$(dirname $(readlink -f "$0"))
source "${script_dir}/ci-common.sh"

# Get Clear Containers test
go get "${test_repo}"

export USE_DOCKER=true
# Build image
sudo -E make rootfs
sudo -E make image

# Build kernel
sudo -E make kernel-src
sudo -E make kernel

# Setup environment and build components .
pushd "${test_repo_dir}"
sudo -E PATH=$PATH bash .ci/setup.sh
popd

#Vefiry Clear Containers are working before install new image and kernel.
docker run --rm -ti busybox echo "test" | grep "test"

#Install new image
sudo ln -sf "$(pwd)/workdir/container.img" /usr/share/clear-containers/clear-containers.img
