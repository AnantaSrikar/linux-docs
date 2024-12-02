# Virtio-GPU
In this experiment, we will setup virtio-gpu-pci and try to make a simple driver. We will try to understand:
1. How the DRM subsystem works
2. How the virtio-gpu-pci works

## Setup
Compile the linux kernel with the following options:
```
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
```

## Host setup
1. Install `xorg-xauth` on the server.
2. Edit `/etc/ssh/sshd_config`, change `X11Forwarding no` to yes.
3. Modify `run-vm.sh`. Remove `-nographic` and add the following
	```
	-vga none
	-device virtio-pci-gpu
	```

## Client setup
Add the following to `~/.ssh/config`
```
Host *
	ForwardX11 yes
	ForwardX11Trusted yes
```

Now you can run `ssh -X <ip_addr>` to login to you development server

You can use https://github.com/dvdhrm/docs to check if your display is working as intended