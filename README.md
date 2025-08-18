# BIOSaurus

A minimal 64-bit x86 kernel written in C and Assembly.  
It boots from a custom stage1 + stage2 bootloader, switches the CPU into long mode, and jumps into a freestanding C kernel with VGA text output.  

---

## ✨ Features

- Stage 1 boot sector (512 bytes) to load stage 2  
- Stage 2 bootloader:
  - Switches to protected mode → long mode (x86_64)  
  - Sets up page tables and GDT  
  - Copies kernel binary into memory at `0x00100000`  
  - Clears `.bss` before calling the kernel entry  
- Freestanding C kernel:
  - Writes directly to VGA text buffer at `0xB8000`  
  - Minimal VGA console with `clear`, `putc`, `print`  
  - Example kernel entry (`_kernel`) printing `"Hello, kernel world!"`

---

## 🛠 Build

Dependencies:

- **Clang/LLVM** (compiler + lld + objcopy)  
- **NASM** (assembler)  
- **GNU Make**  
- **QEMU** (for testing)

Build everything:

```sh
make
```

This produces:

```
bin/os-image.bin   # final bootable image
```

Run with QEMU:

```sh
make run
```

Clean build artifacts:

```sh
make clean
```

---

## 📂 Project Layout

```
.
├── boot_stage1.nasm     # Stage 1 boot sector (MBR)
├── boot_stage2.nasm     # Stage 2 loader (protected → long mode, loads kernel)
├── kernel.c             # C kernel code (VGA text printing)
├── linker.ld            # Kernel linker script (load at 0x00100000)
├── Makefile             # Build system
└── bin/                 # Build outputs
```

---

## ⚙️ Technical Notes

- Kernel is linked to load at `0x00100000` (1 MB).  
- VGA text mode uses 80×25 characters, each cell = `char + attribute` at `0xB8000`.  
- Entry point `_kernel` is called after `.bss` is zeroed.  
- Stack is set up at `0x90000` (aligned 16 bytes).  
- Paging maps the first 2 MB with 2 MB pages (identity mapping).  

---

## 🚀 Next Steps

- Implement scrolling in VGA console  
- Add keyboard input driver (from PS/2)  
- Replace raw binary loading with ELF parser in stage2  
- Implement simple memory allocator  
