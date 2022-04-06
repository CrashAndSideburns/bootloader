bootloader:
	nasm -o target/bootloader src/stage1.s
disk: bootloader
	mformat -FC -i target/disk.iso -T 66581
	dd if=target/bootloader of=target/disk.iso bs=1 count=446 conv=notrunc
	dd if=target/bootloader of=target/disk.iso bs=1 count=2 skip=510 seek=510 conv=notrunc
qemu: disk
	qemu-system-x86_64 target/disk.iso
