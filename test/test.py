import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotbext.uart import UartSource, UartSink
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.binary import BinaryValue
import logging

logging.basicConfig(level=logging.DEBUG)


def spi_log(dut, message, level="info"):
    """Prepend the 'spi_slave' tag to the log message."""
    full_message = f"spi_slave: {message}"
    if level == "debug":
        dut._log.debug(full_message)
    elif level == "warning":
        dut._log.warning(full_message)
    elif level == "error":
        dut._log.error(full_message)
    elif level == "critical":
        dut._log.critical(full_message)
    else:
        dut._log.info(full_message)


@cocotb.coroutine
def spi_slave(dut, clock, cs, mosi, miso):
    """A simple SPI slave coroutine using a dedicated logger."""
    spi_log(dut, "SPI Slave coroutine started.")
    miso.value = 0

    out_buff = BinaryValue(n_bits=8, bigEndian=False)
    out_buff.binstr = "0" * 8

    yield FallingEdge(cs)
    spi_log(dut, "CS is low, SPI transaction started.")

    for bit_index in range(32):
        yield RisingEdge(clock)
        out_buff = BinaryValue(
            value=(out_buff.value << 1) | mosi.value.integer, n_bits=32, bigEndian=False
        )
        spi_log(dut, f"Read bit {mosi.value.integer}, buffer now {out_buff.binstr}")

        yield FallingEdge(clock)
        miso.value = int(out_buff.binstr[-1])

    assert out_buff.value == 0xDEADBEAF, f"Expected 0xdeadbeaf, got {out_buff.value:#X}"
    spi_log(dut, "Received expected value: 0xdeadbeaf")


@cocotb.test()
async def test_uart(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    spi_task = cocotb.start_soon(
        spi_slave(
            dut,
            dut.spi_sclk0,
            dut.spi_cen0,
            dut.spi_sio0_si_mosi0,
            dut.spi_sio1_so_miso0,
        )
    )

    uart_source = UartSource(dut.uart_rx, baud=115200, bits=8)
    uart_sink = UartSink(dut.uart_tx, baud=115200, bits=8)

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 20000 * 6)

    expected_str = b"Hello UART\n"
    data = uart_sink.read_nowait(len(expected_str))
    dut._log.info(f"UART Data: {data}")
    assert data == expected_str

    # The code should convert these to lowercase and echo them
    await uart_source.write(b"Q")
    await ClockCycles(dut.clk, 2500)
    await uart_source.write(b"A")
    await ClockCycles(dut.clk, 4000)

    data = uart_sink.read_nowait(2)
    dut._log.info(f"UART Data: {data}")
    assert data == b"qa"
