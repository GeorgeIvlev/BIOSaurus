NASM    = nasm
CC      = clang
LD      = ld.lld
OBJCOPY = objcopy
OUTDIR  = bin

.PHONY: all clean run
all: $(OUTDIR)/os-image.bin

$(OUTDIR):
	mkdir -p $@

# Stage 1
$(OUTDIR)/boot_stage1.bin: boot_stage1.nasm | $(OUTDIR)
	$(NASM) -f bin -g $< -o $@

#Stage 2
$(OUTDIR)/boot_stage2.bin: boot_stage2.nasm | $(OUTDIR)
	$(NASM) -f bin -g $< -o $@

# Pad Stage 2 to full sectors
# 	TODO: 2048 bytes is enough for stage 2, but be careful
# 	overflow need to be corrected manually...
$(OUTDIR)/boot_stage2_padded.bin: $(OUTDIR)/boot_stage2.bin
	cp $< $@
	@size=$$(stat -c%s $<); \
	echo "Stage 2 size: $$size bytes"; \
	sectors=$$(( ($$size + 511) / 512 )); \
	echo "Stage 2 sectors: $$sectors"; \
	pad=$$(( 4 * 512 - $$size )); \
	dd if=/dev/zero bs=1 count=$$pad >> $@ 2>/dev/null; \
	echo "Padded to: $$((size + pad)) bytes ($$sectors sectors)"

# Kernel object
$(OUTDIR)/kernel.o: kernel.c | $(OUTDIR)
	$(CC) -target x86_64-pc-none-elf \
	      -ffreestanding \
	      -fno-stack-protector \
	      -nostdlib \
	      -mcmodel=large \
	      -mno-red-zone \
	      -fno-omit-frame-pointer \
	      -O0 \
	      -S -o bin/kernel.s $<   # First generate assembly to check
	$(CC) -target x86_64-pc-none-elf \
	      -ffreestanding \
	      -fno-stack-protector \
	      -nostdlib \
	      -mcmodel=large \
	      -mno-red-zone \
	      -fno-omit-frame-pointer \
	      -O0 \
	      -c $< -o $@

# Kernel ELF
$(OUTDIR)/kernel.elf: $(OUTDIR)/kernel.o linker.ld
	$(LD) -flavor gnu -m elf_x86_64 -T linker.ld -o $@ $(OUTDIR)/kernel.o

# Kernel raw binary
$(OUTDIR)/kernel.bin: $(OUTDIR)/kernel.elf
	$(OBJCOPY) -O binary --set-section-flags .ltext=alloc,load,code $< $@
	@echo "Kernel size: $$(stat -c%s $@) bytes"

# Final image: Stage1 + Stage2(padded) + Kernel
$(OUTDIR)/os-image.bin: $(OUTDIR)/boot_stage1.bin $(OUTDIR)/boot_stage2_padded.bin $(OUTDIR)/kernel.bin
	cat $^ > $@

clean:
	rm -rf $(OUTDIR)

run: $(OUTDIR)/os-image.bin
#	qemu-system-x86_64 -drive format=raw,file=bin/os-image.bin,if=ide
#	qemu-system-x86_64 -drive format=raw,file=bin/os-image.bin,if=floppy
	qemu-system-x86_64 -no-reboot -m 128M -usb -device qemu-xhci -drive format=raw,file=bin/os-image.bin

run-dev: $(OUTDIR)/os-image.bin
	qemu-system-x86_64 -d int,cpu_reset -no-reboot -m 128M -usb -device qemu-xhci -drive format=raw,file=bin/os-image.bin

debug: $(OUTDIR)/os-image.bin
	qemu-system-x86_64 -s -S -d int,cpu_reset -no-reboot -m 128M -usb -device qemu-xhci -drive format=raw,file=bin/os-image.bin