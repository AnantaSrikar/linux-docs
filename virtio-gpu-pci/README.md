# Virtio-GPU
In this experiment, we will setup virtio-gpu-pci and try to make a simple driver. We will try to understand:
1. How the DRM subsystem works
2. How the virtio-gpu-pci works

## Setup
1. Compile the linux kernel with the following options, or use [setup-kernel.sh](scripts/setup-kernel.sh) for faster setup.
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

2. If you compiled the kernel manually without using the script, make sure to build the modules as well.
	```bash
	make modules
	```

## VM setup
We have to install the kernel modules to allow us to load and unload the `VIRTIO_DRM` driver. We also have to use an Ubuntu 24.04 VM, since debian doesn't come with the latest GCC (`gcc-14`), which is needed to install and compile modules on the VM.

1. Use [create-image-ubuntu.sh](scripts/create-image-ubuntu.sh) for making a QEMU bootable Ubuntu image. NOTE: using [create-image.sh](scripts/create-image.sh) would also install all the dependencies needed in the further experimentation. I have included the install commmands just for reference.

2. Boot into the VM using the modified [run-vm.sh](scripts/run-vm.sh), which has the `virtio-gpu-pci` enabled.

3. SSH into the running QEMU VM.
	```bash
	ssh -i image/noble.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost
	```

4. Enable the `universe` apt repository which has the gcc package.
	```bash
	add-apt-repository universe
	```

5. Install `gcc-14` using apt.
	```bash
	apt install gcc-14 -y
	```

6. Make `gcc-14` as the default gcc (gcc-13 is used by default).
	```bash
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 200
	```

7. Now, lets install the compiled kernel modules. Mount the linux directory.
	```bash
	mkdir linux
	mount -t 9p -o trans=virtio,version=9p2000.L linuxshare linux
	```

8. Build and install the modules.
	```bash
	cd linux
	make modules
	make modules_install
	```

You should now have a compatible VM to test your kernel and the modules built for it.

## Checking if DRI is working
1. Install `pkg-config` for buidling the dvdhrm project.
	```bash
	apt install pkg-config -y
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

4. Run `modeset-atomic` to see if the screen displays something.
	```bash
	./modeset-atomic
	```

If the screen displayed colors changing rapidly, then we have our HW emulation ready! Lets move on to some kernel development.


## Unloading kernel module
We have to unload the pre-loaded `virtio-pci` kernel driver to allow a probe on the device from our own kernel module.

Run the following command to unbind the driver
```bash
echo -n 0000:00:04.0 > /sys/bus/pci/drivers/virtio-pci/unbind
```

## Kernel Module Development
There will be few steps that we will follow:
1. Register `virtio-gpu-pci` with the DRM subsystem:
	To do this, we first have to find out the Vendor and Device ID of the `virtio-gpu-pci` device (VID and PID). We can simply run the following to get the info:
	```bash
	lspci -s <pci_dev_string> -n
	```

	The `pci_dev_string` would be something like `00:04.0`, and you can easily find it by running `lspci`. The device we want to target would be something like follows:
	
	```bash
	00:04.0 Display controller: Red Hat, Inc. Virtio 1.0 GPU (rev 01)
	```

	Now that we have the `pci_dev_string`, run `lspci -s 00:04.0 -n`
	```bash
	00:04.0 0380: 1af4:1050 (rev 01)
	```

	We see that the VID is 0x1af4 and DID is 0x1050

	We can write a simple hello world PCI driver as follows: `pci_virtiogpu.c`

	```c
	#include <linux/module.h>
	#include <linux/init.h>
	#include <linux/pci.h>

	#define PCI_VIRTIOGPU_VENDOR_ID 0x1af4
	#define PCI_VIRTIOGPU_DEVICE_ID 0x1050

	MODULE_LICENSE("GPL");
	MODULE_AUTHOR("Ananta Srikar");
	MODULE_DESCRIPTION("Basic DRM driver for virtio-gpu-pci");

	static struct pci_device_id pci_virtiogpu_ids[] = {
		{ PCI_DEVICE(PCI_VIRTIOGPU_VENDOR_ID, PCI_VIRTIOGPU_DEVICE_ID) },
		{ }
	};

	MODULE_DEVICE_TABLE(pci, pci_virtiogpu_ids);

	static int pci_virtiogpu_probe(struct pci_dev *pdev, const struct pci_device_id *id)
	{
		pr_info("pci_virtiogpu: PCI probe function called!\n");
		return 0;
	}

	static void pci_virtiogpu_remove(struct pci_dev *pdev)
	{
		pr_info("pci_virtiogpu: PCI remove function called!\n");
	}

	static struct pci_driver pci_virtiogpu_driver = {
		.name = "virtiogpu",
		.id_table = pci_virtiogpu_ids,
		.probe = pci_virtiogpu_probe,
		.remove = pci_virtiogpu_remove,
	};

	static int __init virtiogpu_init(void)
	{
		pr_info("pci_virtiogpu: Kernel module init called!\n");
		return pci_register_driver(&pci_virtiogpu_driver);
	}

	static void __exit virtiogpu_exit(void)
	{
		pr_info("pci_virtiogpu: Kernel module exit called!\n");
		pci_unregister_driver(&pci_virtiogpu_driver);
	}

	module_init(virtiogpu_init);
	module_exit(virtiogpu_exit);
	```

	Lets also make a corresponding Makefile for the same

	```Makefile
	obj-m += pci_virtiogpu.o

	all:
		make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
	
	clean:
		make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
	```

	Now, build the module by running `make`.

	Load the kernel module by running `insmod pci_virtiogpu.ko`.

	See and verify the debug logs in `dmesg`.

	Once done, unload the kernel module by running `rmmod pci_virtiogpu.ko`.

	Now, lets add some DRM components to the driver.

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

## SSH setup
I prefer to use my homeserver for kernel development, due to it being more powerful. I SSH into my machine for the same, here is the config for that as well.

### SSH Host setup
1. Install `xorg-xauth` on the server.
2. Edit `/etc/ssh/sshd_config`, change `X11Forwarding no` to yes.
3. Modify `run-vm.sh`. Remove `-nographic` and add the following
	```bash
	-vga none
	-device virtio-pci-gpu
	```

### SSH Client setup
Add the following to `~/.ssh/config`
```
Host *
	ForwardX11 yes
	ForwardX11Trusted yes
```

You could also use `ssh -X ip_address` instead, and it should work.

## Notes
- `lspci -s <pci_dev_string> -n` should give you the vendor:device id (the pci_dev_string can be obtained by running lspci, make sure to have pciutils installed)
- https://stackoverflow.com/questions/20111112/unload-kernel-module-for-only-a-specific-device-preferrably-from-code-in-anothe