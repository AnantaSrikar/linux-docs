#!/usr/bin/env bash
# Copyright 2024
# Script to create a bootable QEMU image of Ubuntu 24.04

set -euxo pipefail

# Default preinstalled packages
PREINSTALL_PKGS=openssh-server,curl,tar,gcc,libc6-dev,time,strace,sudo,less,psmisc,systemd-sysv,netplan.io,cloud-init

# Additional packages, configurable via environment variable
if [[ -z ${ADD_PACKAGE+x} ]]; then
    ADD_PACKAGE="make,git,vim,tmux,usbutils,tcpdump"
fi

# Variables affected by options
ARCH=$(uname -m)
RELEASE=noble
FEATURE=minimal
SEEK=2047
PERF=false

# Display help function
display_help() {
    printf "Usage: %s [option...]\n\n" "$0"
    printf "   -a, --arch                 Set architecture (e.g., x86_64, aarch64)\n"
    printf "   -f, --feature              Package set: minimal or full\n"
    printf "   -s, --seek                 Image size in MB (default: 2048)\n"
    printf "   -h, --help                 Display help message\n"
    printf "   -p, --add-perf             Add perf support (requires \$KERNEL set)\n\n"
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            display_help
            exit 0
            ;;
        -a|--arch)
            ARCH=$2
            shift 2
            ;;
        -f|--feature)
            FEATURE=$2
            shift 2
            ;;
        -s|--seek)
            SEEK=$(($2 - 1))
            shift 2
            ;;
        -p|--add-perf)
            PERF=true
            shift 1
            ;;
        -*)
            printf "Error: Unknown option: %s\n" "$1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Architecture mapping for Ubuntu
case "$ARCH" in
    aarch64)
        DEBARCH=arm64
        ;;
    x86_64)
        DEBARCH=amd64
        ;;
    ppc64le|arm|i386)
        DEBARCH=$ARCH
        ;;
    *)
        printf "Error: Unsupported architecture: %s\n" "$ARCH" >&2
        exit 1
        ;;
esac

# Check for foreign architecture
FOREIGN=false
if [[ $ARCH != $(uname -m) ]]; then
    FOREIGN=true
fi

if $FOREIGN; then
    if ! command -v qemu-$ARCH-static &>/dev/null; then
        printf "Please install qemu static binary for architecture %s\n" "$ARCH" >&2
        exit 1
    fi
    if [[ ! -r /proc/sys/fs/binfmt_misc/qemu-$ARCH ]]; then
        printf "binfmt entry for %s does not exist\n" "$ARCH" >&2
        exit 1
    fi
fi

# Handle full feature option
if [[ $FEATURE == "full" ]]; then
    PREINSTALL_PKGS=$PREINSTALL_PKGS","$ADD_PACKAGE
fi

DIR=$RELEASE
sudo rm -rf "$DIR"
sudo mkdir -p "$DIR"
sudo chmod 0755 "$DIR"

# Debootstrap parameters
DEBOOTSTRAP_PARAMS="--arch=$DEBARCH --include=$PREINSTALL_PKGS $RELEASE $DIR"

if $FOREIGN; then
    DEBOOTSTRAP_PARAMS="--foreign $DEBOOTSTRAP_PARAMS"
fi

# Run debootstrap
sudo debootstrap $DEBOOTSTRAP_PARAMS http://archive.ubuntu.com/ubuntu/

# Second stage for foreign architectures
if $FOREIGN; then
    sudo cp "$(command -v qemu-$ARCH-static)" "$DIR/usr/bin/"
    sudo chroot "$DIR" /bin/bash -c "/debootstrap/debootstrap --second-stage"
fi

# Basic configurations
sudo sed -i '/^root/ s/:x:/::/' "$DIR/etc/passwd"
echo 'T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100' | sudo tee -a "$DIR/etc/inittab"
# Create a netplan configuration for DHCP on eth0
sudo mkdir -p "$DIR/etc/netplan"
cat <<EOF | sudo tee "$DIR/etc/netplan/01-netcfg.yaml"
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
EOF

echo '/dev/root / ext4 defaults 0 0' | sudo tee -a "$DIR/etc/fstab"
printf "127.0.0.1\tlocalhost\n" | sudo tee "$DIR/etc/hosts"
echo "nameserver 8.8.8.8" | sudo tee -a "$DIR/etc/resolv.conf"
echo "ubuntu" | sudo tee "$DIR/etc/hostname"

# SSH key setup
ssh-keygen -f "$RELEASE.id_rsa" -t rsa -N ''
sudo mkdir -p "$DIR/root/.ssh"
cat "$RELEASE.id_rsa.pub" | sudo tee "$DIR/root/.ssh/authorized_keys"

# Add perf support if enabled
if $PERF; then
    if [[ -z ${KERNEL+x} ]]; then
        printf "Please set KERNEL environment variable when PERF is enabled\n" >&2
        exit 1
    fi
    sudo cp -r "$KERNEL" "$DIR/tmp/"
    BASENAME=$(basename "$KERNEL")
    sudo chroot "$DIR" /bin/bash -c "apt-get update && apt-get install -y flex bison python3-dev libelf-dev libunwind-dev libaudit-dev libslang2-dev libperl-dev binutils-dev liblzma-dev libnuma-dev"
    sudo chroot "$DIR" /bin/bash -c "cd /tmp/$BASENAME/tools/perf && make"
    sudo chroot "$DIR" /bin/bash -c "cp /tmp/$BASENAME/tools/perf/perf /usr/bin/"
    sudo rm -r "$DIR/tmp/$BASENAME"
fi

# Build the disk image
IMG_NAME="$RELEASE.img"
dd if=/dev/zero of="$IMG_NAME" bs=1M seek="$SEEK" count=1
sudo mkfs.ext4 -F "$IMG_NAME"
MNT_DIR="/mnt/$DIR"
sudo mkdir -p "$MNT_DIR"
sudo mount -o loop "$IMG_NAME" "$MNT_DIR"
sudo cp -a "$DIR/." "$MNT_DIR/."
sudo umount "$MNT_DIR"

printf "Image %s created successfully.\n" "$IMG_NAME"