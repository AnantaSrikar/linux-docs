#!/bin/bash

ADDITIONAL_PACKAGES="make,git,vim,tmux,build-essential,cmake,libdrm-dev,libkmod-dev,libproc2-dev,libdw-dev,libpixman-1-dev,libcairo2-dev,libudev-dev,flex,bison,pciutils,software-properties-common,pkg-config"

mkdir image

cd image
wget "https://raw.githubusercontent.com/AnantaSrikar/linux-docs/refs/heads/master/virtio/create-image-ubuntu.sh" -O create-image.sh
chmod +x create-image.sh
ADD_PACKAGE=$ADDITIONAL_PACKAGES ./create-image.sh -s 20480 --feature full