#!/bin/bash

COMPILER=gcc
LINUX_DIR=linux

cd $LINUX_DIR

make "CC=ccache $COMPILER" defconfig
make "CC=ccache $COMPILER" kvm_guest.config

cat <<EOL >> .config

CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y

CONFIG_CONFIGFS_FS=y
CONFIG_SECURITYFS=y

CONFIG_CMDLINE_BOOL=y
CONFIG_CMDLINE="net.ifnames=0"

# Mounting 9p filesystem for linux-src in guest
CONFIG_NET_9P=y
CONFIG_NET_9P_VIRTIO=y
CONFIG_9P_FS=y
CONFIG_9P_FS_POSIX_ACL=y

CONFIG_PCI=y
CONFIG_VIRTIO_PCI=y

# Kernel GDB
CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=y
CONFIG_GDB_SCRIPTS=y
CONFIG_FRAME_POINTER=y
# CONFIG_RANDOMIZE_BASE is not set

# VKMS kernel driver
CONFIG_DRM_VKMS=m
EOL

make "CC=ccache $COMPILER" olddefconfig

time make "CC=ccache $COMPILER" -j$(nproc)

make "CC=ccache $COMPILER" modules