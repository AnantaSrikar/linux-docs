# VKMS Workflow

In this document, we shall discuss:
1. What is VKMS.
2. How to setup VKMS in a QEMU instance.

## What is VKMS?
From [drm/vkms documentation](https://www.kernel.org/doc/html/latest/gpu/vkms.html), VKMS is a software-only model of a KMS driver that is useful for testing and for running X (or similar) on headless machines. VKMS aims to enable a virtual display with no need of a hardware display capability, releasing the GPU in DRM API tests.

## Setup VKMS
1. Clone the latest kernel. You can find the closest mirror by running `ping git.kernel.org`, and it will start pinging the nearest kernel to you. _This will take anywhere between 5-20 mins, depending on traffic on the mirrors._
	```bash
	git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
	```

2. Change into the cloned linux source code directory.
	```
	cd linux
	```

3. Generate the base QEMU configs.
	```bash
	make defconfig
	make kvm_guest.config
	```

4. Enable required config options for QEMU and syzkaller, mentioned [here](https://github.com/google/syzkaller/blob/master/docs/linux/kernel_configs.md).
	```bash
	cat <<EOL >> .config
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

	CONFIG_PCI=y
	CONFIG_VIRTIO_PCI=y
	EOL
	```

5. Enable the `vkms` experimental kernel module.
	```bash
	cat <<EOL >> .config
	CONFIG_DRM_VKMS=m
	EOL
	```

6. Finalize the config.
	```bash
	make olddefconfig
	```

7. Use `ccache` to compile the kernel. This will greatly improve the kernel compilation times. You can replace gcc with clang, as per your needs. _This will take about 30-40 mins on the first run, depending on PC specs. Subsequent compiles should be under 5 mins, provided you have an SSD._
	```bash
	time make CC="ccache gcc" -j`nproc`
	```

8. Create a qemu disk by using the syzkaller provided `create-image.sh` in a separate directory. _This may take about 5-15 mins depending on PC specs and internet speed._
	```bash
	mkdir image
	cd image
	wget "https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh" -O create-image.sh
	chmod +x create-image.sh
	ADD_PACKAGE="make,git,vim,cscope,universal-tags,tmux,build-essential" ./create-image.sh --distribution bookworm -s 20480 --feature full
	```

9. Log into the QEMU machine via `ssh`.
	```bash
	ssh -i image/bookworm.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost
	```