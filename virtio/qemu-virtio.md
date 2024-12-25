# Virtio-GPU
In this experiment, we will setup virtio-gpu-pci and try to make a simple driver. We will try to understand:
1. How the DRM subsystem works
2. How the virtio-gpu-pci works

## Setup
1. Compile the linux kernel with the following options:
	```bash
	CONFIG_KCOV=y
	CONFIG_KCOV_INSTRUMENT_ALL=y
	CONFIG_KCOV_ENABLE_COMPARISONS=y
	CONFIG_DEBUG_FS=y
	CONFIG_DEBUG_KMEMLEAK=y
	CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=y
	CONFIG_KALLSYMS=y
	CONFIG_KALLSYMS_ALL=y

	CONFIG_NAMESPACES=y
	CONFIG_UTS_NS=y
	CONFIG_IPC_NS=y
	CONFIG_PID_NS=y
	CONFIG_NET_NS=y
	CONFIG_CGROUP_PIDS=y
	CONFIG_MEMCG=y
	CONFIG_USER_NS=y

	CONFIG_CONFIGFS_FS=y
	CONFIG_SECURITYFS=y

	CONFIG_CMDLINE_BOOL=y
	CONFIG_CMDLINE="net.ifnames=0"

	CONFIG_KASAN=y
	CONFIG_KASAN_INLINE=y

	CONFIG_FAULT_INJECTION=y
	CONFIG_FAULT_INJECTION_DEBUG_FS=y
	CONFIG_FAULT_INJECTION_USERCOPY=y
	CONFIG_FAILSLAB=y
	CONFIG_FAIL_PAGE_ALLOC=y
	CONFIG_FAIL_MAKE_REQUEST=y
	CONFIG_FAIL_IO_TIMEOUT=y
	CONFIG_FAIL_FUTEX=y

	CONFIG_LOCKDEP=y
	CONFIG_PROVE_LOCKING=y
	CONFIG_DEBUG_ATOMIC_SLEEP=y
	CONFIG_PROVE_RCU=y
	CONFIG_DEBUG_VM=y
	CONFIG_REFCOUNT_FULL=y
	CONFIG_FORTIFY_SOURCE=y
	CONFIG_HARDENED_USERCOPY=y
	CONFIG_LOCKUP_DETECTOR=y
	CONFIG_SOFTLOCKUP_DETECTOR=y
	CONFIG_HARDLOCKUP_DETECTOR=y
	CONFIG_BOOTPARAM_HARDLOCKUP_PANIC=y
	CONFIG_DETECT_HUNG_TASK=y
	CONFIG_WQ_WATCHDOG=y

	CONFIG_DEFAULT_HUNG_TASK_TIMEOUT=140
	CONFIG_RCU_CPU_STALL_TIMEOUT=100

	CONFIG_NET_9P=y
	CONFIG_NET_9P_VIRTIO=y
	CONFIG_NET_9P_DEBUG=y
	CONFIG_9P_FS=y
	CONFIG_9P_FS_POSIX_ACL=y
	CONFIG_PCI=y
	CONFIG_VIRTIO_PCI=y

	CONFIG_DRM_VIRTIO_GPU=m
	```

2. Boot into the VM, and mount the linux directory
3. Install the kernel modules

## SSH Host setup for testing on remote servers
1. Install `xorg-xauth` on the server.
2. Edit `/etc/ssh/sshd_config`, change `X11Forwarding no` to yes.
3. Modify `run-vm.sh`. Remove `-nographic` and add the following
	```bash
	-vga none
	-device virtio-pci-gpu
	```

## SSH Client setup for testing on remote servers
Add the following to `~/.ssh/config`
```
Host *
	ForwardX11 yes
	ForwardX11Trusted yes
```

Now you can run `ssh -X <ip_addr>` to login to you development server

## VM setup
We will have to use an Ubuntu 24.04 VM, since debian doesn't come with the latest GCC (`gcc-14`), which is needed to install and compile modules on the VM.

1. Use [create-image-ubuntu.sh](create-image-ubuntu.sh) for making a QEMU bootable Ubuntu image.

2. Once done, make sure to install `software-properties-common`
	```bash
	apt install software-properties-common
	```
3. Enable the `universe` apt repository which has the gcc package.
	```bash
	add-apt-repository universe
	```
4. Install `gcc-14` using apt
	```bash
	apt install gcc-14
	```
5. Make `gcc-14` as the default gcc (gcc-13 is used by default)
	```bash
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 200
	```

You should now have a compatible VM to test your kernel and the modules built for it.

## Checking if DRI is working
1. Install `pkg-config` for buidling the dvdhrm project.
	```bash
	apt install pkg-config
	```
2. Clone the `dvdhrm/docs` project. This is good start for testing DRI.
	```bash
	git clone https://github.com/dvdhrm/docs
	```
	
3. Build the project
	```bash
	cd docs/drm-howto
	make
	```

4. 


## Unloading kernel module
We have to unload the pre-loaded `virtio-pci` kernel driver to allow a probe on the device from our own kernel module.

Run the following command to unbind the driver
```bash
echo -n 0000:00:04.0 > /sys/bus/pci/drivers/virtio-pci/unbind
```


## Modifying QEMU
We need to modify the virtio-pci-gpu's PCI VENDOR and DEVICE IDs, so that the `virtio-pci` kernel module doesn't take over the device and we can load our kernel module easily. To avoid that, we will modify the QEMU source code.

1. Get the latest version of QEMU
	```bash
	wget https://download.qemu.org/qemu-9.1.2.tar.xz
	```
2. edit `hw/display/virtio-gpu-pci.c`, and in the function `virtio_gpu_pci_base_class_init`, add the following at the end:
	```c
	// Custom mod for dev
	pcidev_k->vendor_id = 0xfeed;  // Custom vendor ID
	pcidev_k->device_id = 0xface;  // Custom device ID
	```
3. Run the following to compile QEMU
	```bash
	mkdir -p bin/debug/native
	cd bin/debug/native
	../../../configure --enable-debug
	make -j`nproc`
	cd ../../..
	```
4. Test the qemu build
	```bash
	bin/debug/native/x86_64-softmmu/qemu-system-x86_64 -L pc-bios
	```

The above method did not work. I may re-visit this later, but my current focus is on figuing out the DRM subsystem.

## Notes
- `lspci -s <pci_dev_string> -n` should give you the vendor:device id (the pci_dev_string can be obtained by running lspci, make sure to have pciutils installed)
- https://stackoverflow.com/questions/20111112/unload-kernel-module-for-only-a-specific-device-preferrably-from-code-in-anothe