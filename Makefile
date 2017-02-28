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

ifdef http_proxy
BUILD_PROXY = --build-arg http_proxy=$(http_proxy)
RUN_PROXY = --env http_proxy=$(http_proxy)
endif

ifdef https_proxy
BUILD_PROXY += --build-arg https_proxy=$(https_proxy)
RUN_PROXY += --env https_proxy=$(https_proxy)
endif

IMAGE_BUILDER = cc-osbuilder
KERNEL_REPO = https://github.com/clearcontainers/linux.git
WORKDIR ?= $(CURDIR)/workdir

DOCKER_RUN=docker run \
			--runtime runc \
			--privileged \
			-v /dev:/dev \
			$(RUN_PROXY) \
			-ti \
			-v $(WORKDIR):/osbuilder \
			$(IMAGE_BUILDER)

rootfs: docker-build $(WORKDIR)
	$(DOCKER_RUN) rootfs


image: docker-build rootfs $(WORKDIR)
	$(DOCKER_RUN) image

kernel: $(WORKDIR)/linux docker-build
	$(DOCKER_RUN) kernel

docker-build:
	cd scripts; \
	docker build $(BUILD_PROXY) -t $(IMAGE_BUILDER) . 

$(WORKDIR)/linux: $(WORKDIR)
	@echo Clone container kernel from $(KERNEL_REPO);\
	cd $(WORKDIR); \
	git clone --depth=1 $(KERNEL_REPO); \
	cd linux; \
	make clear_containers_defconfig;

$(WORKDIR):
	mkdir -p $(WORKDIR)

help:
	@echo "Usage:"
	@echo "osbuilder Makefile provides three main targets:"
	@echo "        rootfs, image and kernel"
	@echo "All the targets will use a special working directory (WORKDIR)"
	@echo "By default, the working directory is $(WORKDIR)"
	@echo "but can be modified using the Makefile variable WORKDIR, use WORKDIR"
	@echo "variable to set the new WORKDIR directory specifying the full path."
	@echo "Example: "
	@echo "         make TARGET WORKDIR=/tmp "
	@echo "Targets:"
	@echo ""
	@echo "rootfs: generates the rootfs content for the Clear Containers image"
	@echo "        the content will be generated in WORKDIR/rootfs, the rootfs"
	@echo "        content can be modified as needed."
	@echo ""
	@echo "image : generates a Clear Containers image using the content from"
	@echo "        WORKDIR/rootfs, the image will be located in WORKDIR/container.img."
	@echo ""
	@echo "kernel: compiles the kernel source from the directory WORKDIR/linux and"
	@echo "        copies the vmlinux image to WORKDIR/vmlinux.container. If the source "
	@echo "        WORKDIR/linux does not exist, it will clone it from $(KERNEL_REPO)."


