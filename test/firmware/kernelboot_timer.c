// SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@wokwi.com>
// SPDX-FileCopyrightText: © 2023 Hirosh Dabui <hirosh@dabui.de>
// SPDX-License-Identifier: MIT

#include <stdatomic.h>
#include <stdint.h>

#define IO_BASE 0x10000000
#define UART_TX (IO_BASE + 0x0000)
#define UART_RX (IO_BASE + 0x0000)
#define UART_LSR (IO_BASE + 0x0005)
#define UART_DIV (IO_BASE + 0x0010)
#define LSR_THRE 0x20
#define LSR_TEMT 0x40
#define LSR_DR 0x01

volatile char *uart_tx = (char *)UART_TX;
volatile char *uart_rx = (char *)UART_RX;
volatile char *uart_lsr = (char *)UART_LSR;

#define MTIME (*((volatile uint64_t *)0x11004000))

volatile atomic_uint interrupt_occurred = ATOMIC_VAR_INIT(0);

void uart_putc(char c) {
  while (!(*uart_lsr & (LSR_THRE | LSR_TEMT)))
    ;
  *uart_tx = c;
}

char uart_getc() {
  while (!(*uart_lsr & LSR_DR))
    ;
  return *uart_rx;
}

static inline void enable_interrupts() { asm volatile("csrsi mstatus, 8"); }

static inline void disable_interrupts() { asm volatile("csrci mstatus, 8"); }

void setup_timer_interrupt() {
  uint32_t mie;
  asm volatile("csrr %0, mie" : "=r"(mie));
  mie |= (1 << 7);
  asm volatile("csrw mie, %0" ::"r"(mie));
}

__attribute__((naked)) void timer_interrupt_handler(void) {

  asm volatile("addi sp, sp, -124\n"
               "sw x1, 4(sp)\n"
               "sw x2, 8(sp)\n"
               "sw x3, 12(sp)\n"
               "sw x4, 16(sp)\n"
               "sw x5, 20(sp)\n"
               "sw x6, 24(sp)\n"
               "sw x7, 28(sp)\n"
               "sw x8, 32(sp)\n"
               "sw x9, 36(sp)\n"
               "sw x10, 40(sp)\n"
               "sw x11, 44(sp)\n"
               "sw x12, 48(sp)\n"
               "sw x13, 52(sp)\n"
               "sw x14, 56(sp)\n"
               "sw x15, 60(sp)\n"
               "sw x16, 64(sp)\n"
               "sw x17, 68(sp)\n"
               "sw x18, 72(sp)\n"
               "sw x19, 76(sp)\n"
               "sw x20, 80(sp)\n"
               "sw x21, 84(sp)\n"
               "sw x22, 88(sp)\n"
               "sw x23, 92(sp)\n"
               "sw x24, 96(sp)\n"
               "sw x25, 100(sp)\n"
               "sw x26, 104(sp)\n"
               "sw x27, 108(sp)\n"
               "sw x28, 112(sp)\n"
               "sw x29, 116(sp)\n"
               "sw x30, 120(sp)\n"
               "sw x31, 124(sp)\n");
  asm volatile("csrrc t0, mstatus, %0" : : "r"((uint32_t)(1 << 7)) : "t0");
  asm volatile("csrc mstatus, %0" ::"r"((uint32_t)(1 << 3)));

  atomic_store(&interrupt_occurred, 1);
  asm volatile("lw x1, 4(sp)\n"
               "lw x2, 8(sp)\n"
               "lw x3, 12(sp)\n"
               "lw x4, 16(sp)\n"
               "lw x5, 20(sp)\n"
               "lw x6, 24(sp)\n"
               "lw x7, 28(sp)\n"
               "lw x8, 32(sp)\n"
               "lw x9, 36(sp)\n"
               "lw x10, 40(sp)\n"
               "lw x11, 44(sp)\n"
               "lw x12, 48(sp)\n"
               "lw x13, 52(sp)\n"
               "lw x14, 56(sp)\n"
               "lw x15, 60(sp)\n"
               "lw x16, 64(sp)\n"
               "lw x17, 68(sp)\n"
               "lw x18, 72(sp)\n"
               "lw x19, 76(sp)\n"
               "lw x20, 80(sp)\n"
               "lw x21, 84(sp)\n"
               "lw x22, 88(sp)\n"
               "lw x23, 92(sp)\n"
               "lw x24, 96(sp)\n"
               "lw x25, 100(sp)\n"
               "lw x26, 104(sp)\n"
               "lw x27, 108(sp)\n"
               "lw x28, 112(sp)\n"
               "lw x29, 116(sp)\n"
               "lw x30, 120(sp)\n"
               "lw x31, 124(sp)\n"
               "addi sp, sp, 124\n");

  asm volatile("mret\n");
}

int main() {
  setup_timer_interrupt();

  uint64_t interval = 2;
  uint64_t mtimecmp_value;

  volatile uint64_t *mtime = (volatile uint64_t *)0x1100bff8;
  volatile uint64_t *mtimecmp = (volatile uint64_t *)0x11004000;

  mtimecmp_value = *mtime + interval;
  *mtimecmp = mtimecmp_value;

  enable_interrupts();

  while (atomic_load(&interrupt_occurred) == 0) {
    ;
  }

  char *hello_string = "Hello UART\n";
  for (int i = 0; hello_string[i] != '\0'; i++) {
    uart_putc(hello_string[i]);
  }

  while (1) {
    char c = uart_getc();
    if (c >= 'A' && c <= 'Z') {
      c += 32;
    }
    uart_putc(c);
  }

  return 0;
}
