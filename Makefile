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
	$(NASM) -f bin $< -o $@

#Stage 2 (pure bin)
$(OUTDIR)/boot_stage2.bin: boot_stage2.nasm | $(OUTDIR)
	$(NASM) -f bin $< -o $@

# Pad Stage 2 to full sectors (multiple of 512)
$(OUTDIR)/boot_stage2_padded.bin: $(OUTDIR)/boot_stage2.bin
	cp $< $@
	@size=$$(stat -c%s $@); \
	  pad=$$(( (512 - ($$size % 512)) % 512 )); \
	  dd if=/dev/zero bs=1 count=$$pad >> $@ 2>/dev/null

# Kernel object
$(OUTDIR)/kernel.o: kernel.c | $(OUTDIR)
	$(CC) -target x86_64-pc-none-elf -ffreestanding -m64 -c $< -o $@

# Kernel ELF
$(OUTDIR)/kernel.elf: $(OUTDIR)/kernel.o linker.ld
	$(LD) -flavor gnu -m elf_x86_64 -T linker.ld -o $@ $(OUTDIR)/kernel.o

# Kernel raw binary
$(OUTDIR)/kernel.bin: $(OUTDIR)/kernel.elf
	$(OBJCOPY) -O binary $< $@

# Final image: Stage1 + Stage2(padded) + Kernel
$(OUTDIR)/os-image.bin: $(OUTDIR)/boot_stage1.bin $(OUTDIR)/boot_stage2_padded.bin $(OUTDIR)/kernel.bin
	cat $^ > $@

clean:
	rm -rf $(OUTDIR)

run: $(OUTDIR)/os-image.bin
#	qemu-system-x86_64 -drive format=raw,file=bin/os-image.bin,if=ide
#	qemu-system-x86_64 -drive format=raw,file=bin/os-image.bin,if=floppy
	qemu-system-x86_64 -drive format=raw,file=bin/os-image.bin