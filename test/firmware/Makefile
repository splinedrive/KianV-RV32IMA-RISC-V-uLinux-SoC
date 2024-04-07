# SPDX-FileCopyrightText: © 2023 Uri Shaked   <uri@wokwi.com>
#                           2023 Hirosh Dabui <hirosh@dabui.de>
# SPDX-License-Identifier: MIT
TOOLCHAIN_PREFIX ?= riscv32-unknown-elf

LDS_FILE ?= kianv.ld
START_FILE = crt0.S
INCLUDE_DIR = .
FILE = kernelboot.c
OPT_LEVEL ?= -Os
FILEwoSUFFIX = $(basename $(FILE))
RVCPPFLAGS = -fno-exceptions -fno-enforce-eh-specs
RVLDFLAGS = -Wl,-melf32lriscv -Wl,-belf32-littleriscv -Wl,--no-relax
RVCFLAGS = -fno-pic -march=rv32ima -mabi=ilp32  -fno-stack-protector -w -Wl,--no-relax -ffreestanding -Wl,--strip-debug,-Map=firmware.map -nostartfiles

all: firmware.hex

firmware.hex: firmware.bin
	echo "@100000" > firmware.hex
	hexdump -v -e '"" 32/1 "%02x " "\n"' firmware.bin >> firmware.hex
crt0.o: $(START_FILE)
	$(TOOLCHAIN_PREFIX)-as $(START_FILE) -o crt0.o

$(FILEwoSUFFIX).s: $(FILE)
	$(TOOLCHAIN_PREFIX)-gcc -S -fverbose-asm  $(OPT_LEVEL) $(RVCFLAGS) -I$(INCLUDE_DIR) $< $(START_FILE) -c

$(FILEwoSUFFIX).lst: $(FILEwoSUFFIX).s
	$(TOOLCHAIN_PREFIX)-as -alhnd $< > $@

$(FILEwoSUFFIX).o: $(FILE)
	$(TOOLCHAIN_PREFIX)-gcc $(OPT_LEVEL) $(RVCFLAGS) -I$(INCLUDE_DIR) $< $(START_FILE) -c

firmware.elf: crt0.o $(FILEwoSUFFIX).o
	$(TOOLCHAIN_PREFIX)-gcc $(OPT_LEVEL) $(RVCFLAGS) $(RVLDFLAGS) -T$(LDS_FILE) -o $@ crt0.o $(FILEwoSUFFIX).o -lc -lm -lgcc

firmware.bin: firmware.elf
	$(TOOLCHAIN_PREFIX)-objcopy -O binary $< $@

clean:
	rm -f *.o *.elf *.bin *.lst *.s

.PHONY: all clean

