#!/bin/bash
LINUX_SRC=linux
RAM=16G
CORES=16
IMAGE=noble
qemu-system-x86_64 \
	-m $RAM \
	-smp $CORES \
	-kernel $LINUX_SRC/arch/x86/boot/bzImage \
	-append "console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0" \
	-drive file=image/$IMAGE.img,format=raw \
	-net user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:10021-:22 \
	-net nic,model=e1000 \
	-virtfs local,path=$LINUX_SRC,mount_tag=linuxshare,security_model=none,id=linuxshare \
	-enable-kvm \
	-vga none \
	-device virtio-gpu-pci \
	-pidfile vm.pid \
	-s \
	2>&1 | tee vm.log