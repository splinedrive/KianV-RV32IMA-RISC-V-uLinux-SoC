/* SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@wokwi.com>
   SPDX-FileCopyrightText: © 2023 Hirosh Dabui <hirosh@dabui.de>
   SPDX-License-Identifier: MIT */
.text
.global _start, timer_interrupt_handler

#define IO_BASE 0x10000000
#define REG_DIV (IO_BASE + 0x0010)
#define SPI_REG_DIV (IO_BASE + 0x500000 + 0x0010)
.equ FREQ, 10000000
.equ DIVISOR1, 1000
.equ SPI_DATA_RATE, 100000
.equ BAUDRATE, 115200
.equ REG_DIV_VAL, ((FREQ / DIVISOR1) << 16) | (FREQ / BAUDRATE)
.equ SPI_REG_DIV_VAL, (FREQ / SPI_DATA_RATE)

.type _start, @function
_start:
    la t0, REG_DIV
    li t1, REG_DIV_VAL
    sw t1, 0(t0)

    la t0, SPI_REG_DIV
    li t1, SPI_REG_DIV_VAL
    sw t1, 0(t0)

    la sp, __stacktop

    la a0, _sbss
    la a1, _ebss
1:  sw zero, 0(a0)
    addi a0, a0, 4
    blt a0, a1, 1b

    la a0, _sidata
    la a1, _sdata
    la a2, _edata
2:  lw a3, 0(a0)
    sw a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    blt a1, a2, 2b

    la a0, timer_interrupt_handler
    csrw mtvec, a0

    call main
3:  j 3b
.balign 4

