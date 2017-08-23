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

.PHONY: rootfs image kernel check-deps

ifdef http_proxy
BUILD_PROXY = --build-arg http_proxy=$(http_proxy)
RUN_PROXY = --env http_proxy=$(http_proxy)
endif

ifdef https_proxy
BUILD_PROXY += --build-arg https_proxy=$(https_proxy)
RUN_PROXY += --env https_proxy=$(https_proxy)
endif

IMAGE_BUILDER = cc-osbuilder
WORKDIR ?= $(CURDIR)/workdir
MK_DIR :=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
OS_BUILDER ?= $(MK_DIR)/scripts/osbuilder.sh


ifdef USE_DOCKER
DOCKER_DEPS += docker-build
OS_BUILDER = docker run \
			--runtime runc \
			--privileged \
			-v /dev:/dev \
			$(RUN_PROXY) \
			-i \
			-v $(WORKDIR):/osbuilder \
			$(IMAGE_BUILDER)
endif
rootfs: $(WORKDIR) $(DOCKER_DEPS)
	cd $(WORKDIR) && rm -rf "$(WORKDIR)/rootfs" && $(OS_BUILDER) rootfs


image: rootfs $(WORKDIR) $(DOCKER_DEPS)
	cd $(WORKDIR) && $(OS_BUILDER) image

kernel: $(DOCKER_DEPS)
	cd $(WORKDIR) && $(OS_BUILDER) kernel

ifdef KERNEL_TAG
KERNEL_TAG_OPT =-t $(KERNEL_TAG)
endif

ifdef KERNEL_REPO
KERNEL_REPO_OPT =-k $(KERNEL_REPO)
endif

kernel-src: $(WORKDIR) $(DOCKER_DEPS)
	cd $(WORKDIR) && $(OS_BUILDER)  $(KERNEL_TAG_OPT) $(KERNEL_REPO_OPT) kernel-src

docker-build:
	cd scripts; \
	docker build $(BUILD_PROXY) -t $(IMAGE_BUILDER) . 


$(WORKDIR):
	mkdir -p $(WORKDIR)

define check_program
    ( printf "check for $1..." && type $1 >/dev/null 2>&1 && echo "yes" ) || ( echo "no" && false )

endef

check-deps:
ifdef USE_DOCKER
	@$(call check_program,docker)
else
	@$(call check_program,dnf)
	@$(call check_program,yum)
	@$(call check_program,qemu-img)
	@$(call check_program,parted)
	@$(call check_program,gdisk)
	@$(call check_program,make)
	@$(call check_program,gcc)
	@$(call check_program,bc)
	@$(call check_program,git)
endif

help:
	@echo "Usage:"
	@echo "osbuilder Makefile provides the targets:"
	@echo "        rootfs, image, kernel-src and kernel"
	@echo ""
	@echo "ENV variables:"
	@echo ""
	@echo "- WORKDIR:"
	@echo "All the targets will use a special working directory (WORKDIR)"
	@echo "By default, the working directory is $(WORKDIR)"
	@echo "but can be modified using the Makefile variable WORKDIR, use WORKDIR"
	@echo "variable to set the new WORKDIR directory specifying the full path."
	@echo "Example: "
	@echo "         make TARGET WORKDIR=/tmp "
	@echo ""
	@echo "- REPO_URL"
	@echo "use it to change the where rootfs base packages will be downloaded"
	@echo ""
	@echo "Targets:"
	@echo ""
	@echo "rootfs: generates the rootfs content for the Clear Containers image"
	@echo "        the content will be generated in WORKDIR/rootfs, the rootfs"
	@echo "        content can be modified as needed."
	@echo ""
	@echo "image : generates a Clear Containers image using the content from"
	@echo "        WORKDIR/rootfs, the image will be located in WORKDIR/container.img."
	@echo ""
	@echo "kernel-src: Download and setup the latest clear containers kernel source"
	@echo "            in directory WORKDIR/linux. The kernel source will be used by"
	@echo "            'kernel' target to build it."
	@echo "kernel: compiles the kernel source from the directory WORKDIR/linux. To get"
	@echo "        the latest kernel use 'make kernel-src'"


