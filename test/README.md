# Testbench for KianV uLinux SoC

The testbench loads a simple RISC-V program that prints a message to the UART port,
and then echos all bytes received on the UART port, converting them to uppercase.

## Setup

```bash
pip install -r requirements.txt
```

## Running the tests

```bash
make clean all
```

## Viewing the waveforms

```bash
gtkwave tb.vcd tb.gtkw
```

## Recompilining the test firmware

You need the [RISC-V toolchain](https://static.dev.sifive.com/dev-tools/freedom-tools/v2020.12/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14.tar.gz) installed, in your path. Then run:

```bash
make -C firmware clean firmware.hex
```
