ASM    = nasm
CC      = clang
LD      = ld.lld
OBJCOPY = objcopy
OUTDIR  = build

ASMFLAGS = -f bin
CFLAGS = -m64 -mno-red-zone -fno-pic -fno-stack-protector \
         -nostdlib -nodefaultlibs -Wall -Wextra -O2 \
         -target x86_64-unknown-none-elf -fno-builtin-memset -fno-builtin-memcpy
LDFLAGS = -m elf_x86_64 -T kernel/linker.ld

# Directories
BUILD_DIR = build
BOOT_DIR = boot
KERNEL_DIR = kernel

# Output files
STAGE1 = $(BUILD_DIR)/stage1.bin
STAGE2 = $(BUILD_DIR)/stage2.bin
KERNEL_ELF = $(BUILD_DIR)/kernel.elf
KERNEL_BIN = $(BUILD_DIR)/kernel.bin
OS_IMAGE = $(BUILD_DIR)/os-image.img

# Source files
KERNEL_ASM_SRC = $(wildcard $(KERNEL_DIR)/*.nasm)
KERNEL_ASM_OBJ = $(patsubst $(KERNEL_DIR)/%.nasm, $(BUILD_DIR)/%.o, $(KERNEL_ASM_SRC))

KERNEL_C_SOURCES = $(KERNEL_DIR)/entry.c \
                   $(KERNEL_DIR)/init.c \
                   $(filter-out $(KERNEL_DIR)/entry.c $(KERNEL_DIR)/init.c, $(wildcard $(KERNEL_DIR)/*.c))

KERNEL_C_OBJ = $(patsubst $(KERNEL_DIR)/%.c, $(BUILD_DIR)/%.o, $(KERNEL_C_SOURCES))

KERNEL_OBJ = $(KERNEL_C_OBJ) $(KERNEL_ASM_OBJ)

.PHONY: all clean run kernel

all: $(OS_IMAGE)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Build stage1 (bootloader)
$(STAGE1): $(BOOT_DIR)/stage1.nasm | $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $< -o $@

# Build stage2
$(STAGE2): $(BOOT_DIR)/stage2.nasm | $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $< -o $@

$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.nasm | $(BUILD_DIR)
	$(ASM) -f elf64 $< -o $@

# Compile C kernel objects
$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Link kernel ELF
$(KERNEL_ELF): $(KERNEL_OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

# Extract flat binary from ELF
$(KERNEL_BIN): $(KERNEL_ELF)
	objcopy -O binary $< $@

# Create bootable disk image
$(OS_IMAGE): $(STAGE1) $(STAGE2) $(KERNEL_BIN)
	dd if=/dev/zero of=$@ bs=512 count=2880  # 1.44MB floppy
	dd if=$(STAGE1) of=$@ bs=512 count=1 conv=notrunc  # Sector 0
	dd if=$(STAGE2) of=$@ bs=512 seek=1 count=4 conv=notrunc  # Sectors 1-4
	dd if=$(KERNEL_BIN) of=$@ bs=512 seek=5 conv=notrunc  # Sector 5+

# Quick rebuild: only recompile C kernel
kernel: $(KERNEL_BIN)
	dd if=$(KERNEL_BIN) of=$(OS_IMAGE) bs=512 seek=5 conv=notrunc
	@echo "Kernel updated in $(OS_IMAGE)"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

run: $(OUTDIR)/os-image.img
	qemu-system-x86_64 -no-reboot -m 128M -usb -device qemu-xhci -drive format=raw,file=$(OS_IMAGE)

run-dev: $(OUTDIR)/os-image.img
	qemu-system-x86_64 -d int,cpu_reset -no-reboot -m 128M -usb -device qemu-xhci -drive format=raw,file=$(OS_IMAGE)

debug: $(OUTDIR)/os-image.img
	qemu-system-x86_64 -s -S -d int,cpu_reset -no-reboot -m 128M -usb -device qemu-xhci -drive format=raw,file=$(OS_IMAGE)