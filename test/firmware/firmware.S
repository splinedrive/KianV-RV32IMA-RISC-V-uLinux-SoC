# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@wokwi.com>
# SPDX-License-Identifier: MIT

.section .text
.globl _start

#define IO_BASE      0x10000000
#define UART_TX      (IO_BASE + 0x0000)
#define UART_RX      (IO_BASE + 0x0000)
#define UART_LSR     (IO_BASE + 0x0005)
#define UART_DIV     (IO_BASE + 0x0010)
#define LSR_THRE     0x20
#define LSR_TEMT     0x40
#define LSR_DR       0x01

.equ FREQ,         10000000
.equ DIVISOR1,     10000
.equ BAUDRATE,     115200
.equ UART_DIV_VAL, ((FREQ / DIVISOR1) << 16) | (FREQ / BAUDRATE)

_start:
    # UART initialization
    li t0, UART_DIV       # Load address of UART_DIV
    li t1, UART_DIV_VAL   # Calculated UART divider value
    sw t1, 0(t0)          # Store result to UART_DIV

    # Print "Hello UART\n"
    la a0, hello_string   # Load address of hello string
print_hello:
    lbu a1, 0(a0)         # Load next char from string
    beqz a1, read_char_echo  # If char is 0, jump to read_char_echo
    addi a0, a0, 1        # Increment string pointer

    # uart_putc: a1: char to send
    li t0, UART_LSR
wait_for_uart_ready_to_send:
    lbu t1, 0(t0)         # Load UART_LSR
    andi t1, t1, LSR_THRE | LSR_TEMT
    beqz t1, wait_for_uart_ready_to_send  # If not ready, repeat
    li t0, UART_TX
    sb a1, 0(t0)          # Store char to UART_TX
    j print_hello         # Repeat for next char

read_char_echo:
    # uart_getc
    li t0, UART_RX
    li t1, UART_LSR
wait_for_uart_data:
    lbu t2, 0(t1)         # Load UART_LSR
    andi t2, t2, LSR_DR   # Check if data ready
    beqz t2, wait_for_uart_data  # If not, repeat
    lbu a0, 0(t0)         # Load char from UART_RX

    # Convert to lowercase if uppercase
    li t1, 'A' - 1
    li t2, 'Z'
    blt a0, t1, echo_char  # If char < 'A'
    bgt a0, t2, echo_char  # If char > 'Z'
    li t1, 32  # ASCII difference between upper and lower case
    add a0, a0, t1  # Convert to lowercase

echo_char:
    # uart_putc: a0: char to send
    li t0, UART_LSR
wait_for_uart_ready_to_echo:
    lbu t1, 0(t0)         # Load UART_LSR
    andi t1, t1, LSR_THRE | LSR_TEMT
    beqz t1, wait_for_uart_ready_to_echo  # If not ready, repeat
    li t0, UART_TX
    sb a0, 0(t0)          # Store char to UART_TX
    j read_char_echo      # Repeat for next char

hello_string:
    .asciz "Hello UART\n"
