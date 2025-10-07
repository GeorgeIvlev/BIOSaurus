# BIOSaurus 🦖

A minimal 64-bit x86 kernel written in C and Assembly.  
It boots from a custom stage1 + stage2 bootloader, switches the CPU into long mode, and jumps into a freestanding C kernel.  

---

## ✨ Features

- Stage 1 boot sector (512 bytes) to load stage 2  
- Stage 2 bootloader ( 2048 bytes fixed ):
  - Switches to protected mode → long mode (x86_64)  
  - Sets up page tables and GDT  
  - Copies kernel binary into memory at `0x00100000`  
  - Clears `.bss` before calling the kernel entry  
- Basic C kernel:
  - Writes directly to VGA text buffer at `0xB8000`
  - Example kernel entry (`_kernel`)
  - Basic interrupts implementation
  - Basic support for PIC keyboard driver and PIC mouse driver ( not working right now )
  - Switch to VGA pixel mode ( 320x200 ) with bytes send to gpu registers

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
build/os-image.img   # final bootable image
```

Run with QEMU ( builds all automatically ):

```sh
make run
```

Build kernel ( C code ) only:

```sh
make kernel
```

Run with QEMU development mode:

```sh
make run-dev
```

Run with QEMU debug mode ( gdb can connect ):

```sh
make debug
```

Clean build artifacts:

```sh
make clean
```

---

## 📂 Project Layout

```
.
├── boot/stage1.nasm     # Stage 1 boot sector (MBR)
├── boot/stage2.nasm     # Stage 2 loader (protected → long mode, loads kernel)
├── kernel/entry.c       # C kernel etry code
├── linker.ld            # Kernel linker script (load at 0x00100000)
├── Makefile             # Build system
└── build/               # Build outputs
```