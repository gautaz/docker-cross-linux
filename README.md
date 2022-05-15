# Cross-compiled Linux systems with Docker

This project provides a Docker recipe to build self-sufficient kernel images for my embedded boards.

It roughly goes through the following steps:
* build a cross toolchain with [crosstool-NG](https://crosstool-ng.github.io/)
* cross-compile a [Linux kernel](https://www.kernel.org/)
* cross-compile [BusyBox](https://busybox.net/)
* add BusyBox in the kernel as an [initramfs](https://www.kernel.org/doc/Documentation/filesystems/ramfs-rootfs-initramfs.txt)
* provides the kernel image to the board through [TFTP](https://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol)

The base Docker image was initially [Alpine](https://www.alpinelinux.org/) based but was replace by [ArchLinux](https://archlinux.org/) due to [this issue](https://sourceware.org/bugzilla/show_bug.cgi?id=21604).

To start the environment:
* `docker compose build`
* `docker compose up -d`

You should use up to date [docker](https://docs.docker.com/get-docker/) and [compose](https://docs.docker.com/compose/install/) executables in order to benefit from the [buildkit](https://docs.docker.com/develop/develop-images/build_enhancements/)'s cache.

## Toshiba RBTX4938

This is the first board I am experimenting with.
The support for these boards [was removed](https://lore.kernel.org/lkml/20211130164558.85584-2-tsbogend@alpha.franken.de/T/) from the kernel sources so I had to revert this commit through a [patch](rbtx4938/linux.patch).

Also few documentation remains related to the YAMON board's ROM monitor:
* https://www.linux-mips.org/wiki/YAMON
* https://linuxlink.timesys.com/docs/wiki/engineering/Yamon
