#!/bin/bash

COMPILER=gcc
LINUX_SRC=linux

cd $LINUX_SRC

time make CC="ccache $COMPILER" defconfig
time make CC="ccache $COMPILER" kvm_guest.config

cat ../kernelops.conf >> .config

time make CC="ccache $COMPILER" olddefconfig

time make CC="ccache $COMPILER" -j`nproc`

time make CC="ccache $COMPILER" modules