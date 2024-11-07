# Finding and fixing bugs with syzkaller

## Choosing a bug
Some of the easiest bugs to fix on syzkaller are the KASAN and KMSAN bugs, because they are usually due to illegal memory accesses.

Make sure the bug you choose match the following criterion:
- It is _easily_ reproducable. `syzbot` should have made a C reproducer for you.
- Nobody has submitted a patch or is working on it.

## Reproducing and fixing the bug
Make sure to do the following before attempting to fix a bug
- Checkout to the kernel commit mentioned in the bug.
- Boot the qemu machine on the commit
- wget the C repro and try reproducing
- Try the same on the latest kernel

If it works on the latest commit as well, you can go ahead and debug it using the `-s` flag in the qemu run command or script. 

# Some qemu stuff
- Ctrl + A, X to kill a current qemu

## Submitting the patch
Once you've commited your changes, make sure to 
- run the checkpatch.pl script against your patch to make sure your patch adheres to the Kernel coding standards and guidelines.
- Get all the maintainers of the file you just fixed
- CC Shuah and the lkmp mailing list (make sure you're subscribed as well!) asking for feedback on the bug fix
- Wait

## Mail Client to be used
Since the Linux community wants only plaintext in their mails, you can use any mail setup listed [here](https://useplaintext.email/)

## References:
- https://javiercarrascocruz.github.io/kernel-contributor-1
- https://javiercarrascocruz.github.io/syzbot