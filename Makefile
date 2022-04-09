all: bootloader filesystem disk

bootloader:
	nasm -o target/bootloader src/stage1.s
filesystem:
	mformat -FC -i target/filesystem.img -T 66581 -H 1
	mmd -i target/filesystem.img ::/boot
	nasm -o target/boot.bin src/stage2.s
	mcopy -i target/filesystem.img target/boot.bin ::/boot/boot.bin
disk: bootloader filesystem
	dd if=/dev/zero of=target/disk.img count=66582 conv=notrunc
	parted -s target/disk.img mktable msdos
	parted -s target/disk.img mkpart primary fat32 0 100%
	parted -s target/disk.img set 1 boot on
	dd if=target/bootloader of=target/disk.img bs=1 count=446 conv=notrunc
	dd if=target/bootloader of=target/disk.img bs=1 count=2 skip=510 seek=510 conv=notrunc
	dd if=target/filesystem.img of=target/disk.img seek=1 conv=notrunc
qemu: disk
	qemu-system-x86_64 target/disk.img
