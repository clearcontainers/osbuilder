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

RUN_OS_VERSION= --env OS_VERSION="$(OS_VERSION)"
RUN_AGENT_VERSION= --env AGENT_VERSION="$(AGENT_VERSION)"
RUN_EXTRA_PKGS = --env EXTRA_PKGS="$(EXTRA_PKGS)"
RUN_IMG_SIZE = --env IMG_SIZE="$(IMG_SIZE)"
RUN_REPO_URL = --env REPO_URL="$(REPO_URL)"
RUN_DEBUG = --env DEBUG="$(DEBUG)"
CONTAINER_GOPATH = /go_path
RUN_GOPATH += --env GOPATH="$(CONTAINER_GOPATH)"

IMAGE_BUILDER = cc-osbuilder
WORKDIR ?= $(CURDIR)/workdir
MK_DIR :=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
OS_BUILDER ?= $(MK_DIR)/scripts/osbuilder.sh
RUNTIME_VERSIONS = "https://raw.githubusercontent.com/clearcontainers/runtime/master/versions.txt"
#get go_version=<version>
GO_VERSION = $(shell curl -sL $(RUNTIME_VERSIONS) | grep '^go_version=' | cut -d= -f2)
BUILD_GO_VERSION+= --build-arg GO_VERSION=$(GO_VERSION)

# Installation variables
DESTDIR :=
SYSCONFDIR := /etc
CONFIG_FILE = configuration.toml
DESTDIR :=
DEFAULTSDIR := /usr/share/defaults
CCDIR := clear-containers
IMAGE := $(WORKDIR)/container.img
VMLINUX := $(WORKDIR)/vmlinux.container
VMLINUZ := $(WORKDIR)/vmlinuz.container

DESTCONFDIR := $(abspath $(DESTDIR)/$(DEFAULTSDIR)/$(CCDIR))
DESTSYSCONFDIR := $(abspath $(DESTDIR)/$(SYSCONFDIR)/$(CCDIR))

# Main configuration file location for stateless systems
DESTCONFIG := $(abspath $(DESTCONFDIR)/$(CONFIG_FILE))

# Secondary configuration file location. Note that this takes precedence
# over DESTCONFIG.
DESTSYSCONFIG := $(abspath $(DESTSYSCONFDIR)/$(CONFIG_FILE))

IMAGE_DEST := $(abspath $(DESTSYSCONFDIR)/osbuilder.img)
VMLINUX_DEST := $(abspath $(DESTSYSCONFDIR)/osbuilder-vmlinux)
VMLINUZ_DEST := $(abspath $(DESTSYSCONFDIR)/osbuilder-vmlinuz)

ifdef USE_DOCKER
DOCKER_DEPS += docker-build
OS_BUILDER = docker run \
			--runtime runc \
			--privileged \
			-v /dev:/dev \
			$(RUN_PROXY) \
			$(RUN_OS_VERSION) \
			$(RUN_AGENT_VERSION) \
			$(RUN_EXTRA_PKGS) \
			$(RUN_IMG_SIZE) \
			$(RUN_REPO_URL) \
			$(RUN_GOPATH) \
			$(RUN_DEBUG) \
			-i \
			-v $(MK_DIR):/osbuilder \
			-v $(WORKDIR):/workdir \
			-v $(GOPATH):$(CONTAINER_GOPATH)\
			$(IMAGE_BUILDER) \
			/osbuilder/scripts/osbuilder.sh
endif
rootfs: $(WORKDIR) $(DOCKER_DEPS)
	cd $(WORKDIR) && $(OS_BUILDER) rootfs

image: $(WORKDIR) $(DOCKER_DEPS)
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
	docker build $(BUILD_PROXY) $(BUILD_GO_VERSION) -t $(IMAGE_BUILDER) .

clean:
	sudo rm -rf "$(WORKDIR)/rootfs"
	rm -rf "$(WORKDIR)/linux"
	rm -rf "$(WORKDIR)/img"
	rm -f $(WORKDIR)/clear-dnf.conf  $(WORKDIR)/container.img

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


install-image: $(IMAGE) $(DEFAULT_RUNTIME_CONFIG) $(DESTSYSCONFIG)
	install -D --owner root --group root --mode 0644 "$(IMAGE)" "$(IMAGE_DEST)"
	@echo Adding $(IMAGE_DEST) to configuration.
	@sed -i.bak -e 's!^\(image = ".*"\)!# \1\nimage = "$(IMAGE_DEST)"!g' \
		 $(DESTSYSCONFIG)

get-machine-type: $(DESTSYSCONFIG)
	@echo Checking machine type ...
	$(eval MACHINE_TYPE=$(shell grep -P "^machine_type\s*=\s*" $(DESTSYSCONFIG) | grep -oP '"\K.*(?=")') )
	@echo Machine type is $(MACHINE_TYPE)

install-kernel: $(VMLINUZ) $(VMLINUX) $(DESTSYSCONFIG) get-machine-type
	install -D --owner root --group root --mode 0644 $(VMLINUX) $(VMLINUX_DEST)
	install -D --owner root --group root --mode 0644 $(VMLINUZ) $(VMLINUZ_DEST)
	@echo Configured to use machine type \"$(MACHINE_TYPE)\" using kernel $(KERNEL_PATH)
	@sed -i -e 's!^\(kernel = ".*"\)!# \1\nkernel= "$(KERNEL_PATH)"!g' \
		$(DESTSYSCONFIG)

$(DESTSYSCONFIG): $(DESTCONFIG)
	mkdir -p $(DESTSYSCONFDIR)
	@echo Generating $(DESTSYSCONFIG) from $(DESTCONFIG)
	@echo "# XXX: WARNING: this config was generated by osbuilder on $$(date) from $(DESTCONFIG)" > $(DESTSYSCONFIG)
	@cat $(DESTCONFIG) >> $(DESTSYSCONFIG)


define HELP_MSG
Usage:
	The scripts in this repository are called by running make(1)
	specifying particular targets described below. Each target
	can take optional enviroment variables that can be used to change 
	the tools behaviour.

	$$ make TARGET [ <ENV_VARIABLE=VAR> ... ]

Targets:

rootfs: 
	Generates the rootfs content for the Clear Containers image
	the content will be generated in WORKDIR/rootfs, the rootfs
	content can be modified as needed.

image : 
	Generates a Clear Containers image using the content from
	WORKDIR/rootfs, the image will be located in WORKDIR/container.img.

kernel-src: 
	Download and setup the latest clear containers kernel source
	in directory WORKDIR/linux. The kernel source will be used by
	'kernel' target to build it.
	kernel: compiles the kernel source from the directory WORKDIR/linux. To get
	the latest kernel use 'make kernel-src'
	clean: removes the directory WORKDIR

install-kernel:
	Install kernel created by the 'kernel' target in :
		- VMLINUX_DEST (default: $(VMLINUX_DEST))
		- VMLINUZ_DEST (default: $(VMLINUX_DEST)).
	Also, the kernel path is added to runtime config file DESTSYSCONFIG
	(default: $(DESTSYSCONFIG)), the kernel to be configured will depend
	in the machine type defined in DESTSYSCONFIG, vmlinux for
	pc-lite, otherwise vmlinuz.

install-image:
	install image created by the 'image' target in
	VMLINUX_DEST (default: $(VMLINUX_DEST))
	and also adds the image to runtime config file
	DESTSYSCONFIG (default: $(DESTSYSCONFIG))


Environment Variables:

- AGENT_VERSION:
	Agent tag/commit/branch to install when building rootfs.

- DEBUG

- EXTRA_PKGS:
	The list of extra packages to install separated by spaces, for example
	"a b c". By default this values is empty.

- IMG_SIZE
	Specify the image size in megabytes. In order to support memory hot plug, this
	value must be aligned to 128 (defined by PAGE_SECTION_MASK in the Linux Kernel),
	otherwise memory will not be plugged by the guest Linux Kernel, If this value
	is not aligned, osbuilder will align it. By default this value is 128.

- OS_VERSION:
	Clear Linux version to use as base rootfs.

- PKG_MANAGER
	Specify the path to dnf or yum.

- REPO_URL
	Use it to change the where rootfs base packages will be downloaded.

- USE_DOCKER
	Use a docker container to build an image (useful when depedencies are
	not installed).

- WORKDIR:
	All the targets will use a special working directory (WORKDIR)
	By default, the working directory is:
	 -> $(WORKDIR)

	This can be modified using the Makefile variable WORKDIR, use WORKDIR
	variable to set the new WORKDIR directory specifying the full path.
	Example:
	 	$$ make TARGET WORKDIR=/tmp

endef

export HELP_MSG
help:
	@echo "$${HELP_MSG}"
