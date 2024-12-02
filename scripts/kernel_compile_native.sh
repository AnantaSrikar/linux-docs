#!/bin/bash

LINUXVER=linuxgpu
SRC_DIR=linux
COMPILER=gcc

cd $SRC_DIR

zcat /proc/config.gz > .config

make CC="ccache $COMPILER" olddefconfig

make CC="ccache $COMPILER" -j$(nproc) scripts_gdb
make CC="ccache $COMPILER" -j$(nproc)
make CC="ccache $COMPILER" -j$(nproc) modules
sudo make CC="ccache $COMPILER" modules_install

sudo make CC="ccache $COMPILER" -j$(nproc) bzImage
sudo cp arch/x86/boot/bzImage /boot/vmlinuz-$LINUXVER

sudo mkinitcpio -p $LINUXVER

sudo update-grub
sudo grub-reboot "1>2"
sudo reboot