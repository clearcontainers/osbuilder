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

From fedora:27

RUN dnf install -y qemu-img parted gdisk make gcc bc git e2fsprogs libudev-devel pkgconfig elfutils-libelf-devel

ARG GO_VERSION

RUN cd /tmp && curl -OL https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz
RUN tar -C /usr/ -xzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz
ENV GOROOT=/usr/go
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin

ENV workdir /workdir
WORKDIR ${workdir}
