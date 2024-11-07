# Kselftest workflow

I am trying to run it for eBPF tests. 

1. Clone the latest kernel. You can find the closest mirror by running `ping git.kernel.org`, and it will start pinging the nearest kernel to you.
	```bash
	git clone https://nyc.source.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
	```

2. Generate the configs by running
	```bash
	make defconfig
	make kvm_guest.config
	```

3. Enable required config options from syzkaller, mentioned [here](https://github.com/google/syzkaller/blob/master/docs/linux/kernel_configs.md)
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
	CONFIG_UTS_NS=`y
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

4. Enable additional configs as required. You can use `make menuconfig` to enable BPF, which I will be using in my case. Or you could add the following:
	```bash
	cat <<EOL >> .config
	CONFIG_BPF=y
	CONFIG_HAVE_EBPF_JIT=y
	CONFIG_ARCH_WANT_DEFAULT_BPF_JIT=y
	# BPF subsystem
	CONFIG_BPF_SYSCALL=y
	CONFIG_BPF_JIT=y
	CONFIG_BPF_JIT_ALWAYS_ON=y
	CONFIG_BPF_JIT_DEFAULT_ON=y
	CONFIG_BPF_UNPRIV_DEFAULT_OFF=y
	CONFIG_BPF_PRELOAD=y
	CONFIG_BPF_PRELOAD_UMD=m
	CONFIG_BPF_LSM=y
	# end of BPF subsystem
	CONFIG_CGROUP_BPF=y
	CONFIG_NETFILTER_BPF_LINK=y
	CONFIG_NET_CLS_BPF=y
	CONFIG_NET_ACT_BPF=y
	CONFIG_BPF_STREAM_PARSER=y
	# HID-BPF support
	# end of HID-BPF support
	CONFIG_BPF_EVENTS=y
	CONFIG_TEST_BPF=m
	CONFIG_DEBUG_INFO_BTF=y
	CONFIG_PAHOLE_HAS_SPLIT_BTF=y
	CONFIG_DEBUG_INFO_BTF_MODULES=y
	CONFIG_PROBE_EVENTS_BTF_ARGS=y
	EOL
	```
5. To finalize the config, run
	```bash
	make olddefconfig
	```

6. Use ccache to compile the kernel. This will greatly improve the kernel compilation times. You can replace gcc with clang, as per your needs.
	```bash
	time make CC="ccache gcc" -j`nproc`
	```

7. Make sure to create a qemu disk by using the syzkaller provided `create-image.sh` in a separate directory
	```bash
	mkdir image
	cd image
	wget "https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh" -O create-image.sh
	chmod +x create-image.sh
	./create-image.sh --distribution bookworm -s 20480
	```

8. I use a custom `run-vm.sh` script that I made to run the VM
	```bash
	#!/bin/bash
	LINUX_SRC=linux
	RAM=16
	CORES=16
	qemu-system-x86_64 \
		-m $RAMG \
		-smp $CORES \
		-kernel $LINUX_SRC/arch/x86/boot/bzImage \
		-append "console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0" \
		-drive file=image/bookworm.img,format=raw \
		-net user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:10021-:22 \
		-net nic,model=e1000 \
		-virtfs local,path=$LINUX_SRC,mount_tag=linuxshare,security_model=mapped,id=linuxshare \
		-enable-kvm \
		-nographic \
		-pidfile vm.pid \
		-s \
		2>&1 | tee vm.log
	```

9. You can ssh into the VM by running the following:
	```bash
	ssh -i image/bookworm.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost
	```

10. To mount the linux source code directory inside the VM, you can run the following INSIDE the VM
	```bash
	mkdir linux
	mount -t 9p -o trans=virtio,version=9p2000.L linuxshare linux
	```

11. Install the necessary tools for working with the kernel in the VM
	```bash
	apt update
	apt install -y git build-essential vim cscope universal-ctags
	```

12. For eBPF specific stuff
	```bash
	apt install -y llvm-16 clang-16 libelf-dev
	```

13. Make sure the system uses the installed clang and llvm as default
	```
	update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-16 200
	update-alternatives --install /usr/bin/clang clang /usr/bin/clang-16 200
	```

## Runnings `kselftests`
1. SSH into the VM by running:
	```bash
	ssh -i image/bookworm.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost
	```

2. Mount the `linux` source code directory from host. This has to be run everytime the VM boots up.
	```bash
	mount -t 9p -o trans=virtio,version=9p2000.L linuxshare linux
	```

3. Run the following to build the `kselftests`. These steps are taken from [here](https://docs.kernel.org/dev-tools/kselftest.html)
	```bash
	cd linux
	make TARGETS="bpf" kselftest
	```


## Browsing the linux kernel
I'm not sure how I am going to go about this. I am planning on using `vim` with `cscope` and `ctags`. I may have to install additional plugins, but here are the steps I am going to start out with
1. Build the `cscope` database with the following command, inside the linux src directory.
	```bash
	make CC="ccache gcc" -j`nproc` cscope
	```

2. Make `ctags` by running:
	```bash
	ctags -R
	```

3. Display whitespaces
	```vim
	:set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
	:set list
	```
4. Hide whitespaces
	```vim
	:set nolist
	```

5. A better version of whitespace rendering. More info [here](https://stackoverflow.com/questions/1675688/make-vim-show-all-white-spaces-as-a-character)
	```vim
	:syntax on
	:set syntax=whitespace
	```

## Notes
- You can just run `cat .config | grep BPF` or replace BPF with BTF to see what all configs you can enable, or just view the possible options you can enable
- https://www.cyberciti.biz/faq/how-to-display-line-number-in-vim/
- https://cscope.sourceforge.net/cscope_vim_tutorial.html
- https://www.mankier.com/1/lz4
- Checkout CoC vim autocompletion later
- https://www.youtube.com/watch?v=9NcM-Tj2UZI
- https://www.youtube.com/watch?v=GjhqSvfy7xw
- https://docs.kernel.org/dev-tools/kselftest.html