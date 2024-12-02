#!/bin/bash

ADDITIONAL_PACKAGES="make,git,vim,cscope,universal-ctags,tmux,build-essential,meson,ninja-build,pkg-config,cmake,libdrm-dev,libkmod-devi,libproc2-dev,libdw-dev,libpixman-1-dev,libcairo2-dev,libudev-dev,flex,bison,libdrm-tests"

mkdir image

cd image
wget "https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh" -O create-image.sh
chmod +x create-image.sh
ADD_PACKAGE=$ADDITIONAL_PACKAGES ./create-image.sh --distribution bookworm -s 20480 --feature full