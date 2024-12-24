## How it works

32-bit RISC-V IMA processor, capable of booting Linux. Features 16 MiB of external SPI flash memory, 8 MiB of external PSRAM, a UART peripheral, and a SPI peripheral.

## System Memory Map

The system memory map is as follows:

| Address    | Size   | Purpose              |
| ---------- | ------ | -------------------- |
| 0x10000000 | 0x14   | UART Peripheral      |
| 0x10500000 | 0x14   | SPI Peripheral       |
| 0x11100000 | 0x04   | Reset / HALT control |
| 0x20000000 | 16 MiB | SPI Flash            |
| 0x80000000 | 8 MiB  | PSRAM                |

The system boots from the SPI flash memory. After reset, the CPU starts executing code from 0x20100000 (corresponding to the offset 0x100000 into the SPI flash memory), where the bootloader is expected to be.

### UART Peripheral registers

| Address    | Name      | Description                        |
| ---------- | --------- | ---------------------------------- |
| 0x10000000 | UART_DATA | Write to transmit, read to receive |
| 0x10000005 | UART_LSR  | UART line status register          |
| 0x10000010 | UART_DIV  | Clock divider for UART baud rate   |

### SPI Peripheral registers

| Address    | Name      | Description                      |
| ---------- | --------- | -------------------------------- |
| 0x10500000 | SPI_CTRL0 | SPI Peripheral Control           |
| 0x10500004 | SPI_DATA0 | SPI Data                         |
| 0x10500010 | SPI_DIV   | Clock divider for SPI peripheral |

### CPU control register

| Address    | Name      | Description                                            |
| ---------- | --------- | ------------------------------------------------------ |
| 0x11100000 | CPU_RESET | Write 0x7777 to reset the CPU, 0x5555 to halt the CPU. |

## How to test

Build the system image as described in the [kianRiscV repo](https://github.com/splinedrive/kianRiscV/tree/master/asic/os/ulinux_asic_kianv_soc) and load it into the SPI flash memory:

| Flash offset | File name        | Description           |
| ------------ | ---------------- | --------------------- |
| 0x100000     | `bootloader.bin` | Bootloader            |
| 0x180000     | `kianv.dtb`      | Device Tree Blob      |
| 0x200000     | `Image`          | Linux kernel + rootfs |

The system runs at 30 MHz, with a maximum tested speed of 34.5 MHz.

## External hardware

[QSPI Pmod](https://github.com/mole99/qspi-pmod) - can be purchased from the [Tiny Tapeout store](https://store.tinytapeout.com/products/QSPI-Pmod-p716541602).
