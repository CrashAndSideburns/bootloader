all: bootloader disk

bootloader:
	nasm -o target/bootloader src/stage1.s
disk: bootloader
	dd if=/dev/zero of=target/disk.iso count=2049 conv=notrunc
	parted -s target/disk.iso mktable msdos
	parted -s target/disk.iso mkpart primary fat32 0 100%
	parted -s target/disk.iso set 1 boot on
	dd if=target/bootloader of=target/disk.iso bs=1 count=446 conv=notrunc
	dd if=target/bootloader of=target/disk.iso bs=1 count=2 skip=510 seek=510 conv=notrunc
	mkfs.fat -F32 --offset=1 target/disk.iso
qemu: disk
	qemu-system-x86_64 target/disk.iso
