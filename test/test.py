import cocotb
from cocotb.clock import Clock
from cocotb.types import LogicArray
from cocotb.triggers import ClockCycles
from cocotbext.uart import UartSource, UartSink
from cocotb.triggers import RisingEdge, FallingEdge
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


async def spi_slave(dut, clock, cs, mosi, miso):
    """A simple SPI slave coroutine using a dedicated logger."""
    spi_log(dut, "SPI Slave coroutine started.")
    miso.value = 0

    out_buff = LogicArray("0" * 32)

    await FallingEdge(cs)
    spi_log(dut, "CS is low, SPI transaction started.")

    for bit_index in range(32):
        await RisingEdge(clock)
        out_buff[bit_index] = mosi.value
        spi_log(dut, f"Read bit {str(mosi.value)}, buffer now {str(out_buff)}")

        await FallingEdge(clock)
        miso.value = mosi.value

    assert out_buff.value == 0xDEADBEAF, f"Expected 0xdeadbeaf, got {out_buff.value:#X}"
    spi_log(dut, "Received expected value: 0xdeadbeaf")


@cocotb.test()
async def test_uart(dut):
    dut._log.info("start")
    dut.test_sel.value = 0
    clock = Clock(dut.clk, 100, unit="ns")
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
    await uart_source.write(b"K")
    await ClockCycles(dut.clk, 2500)
    await uart_source.write(b"I")
    await ClockCycles(dut.clk, 2500)
    await uart_source.write(b"A")
    await ClockCycles(dut.clk, 2500)
    await uart_source.write(b"N")
    await ClockCycles(dut.clk, 2500)
    await uart_source.write(b"V")
    await ClockCycles(dut.clk, 4000)

    data = uart_sink.read_nowait(5)
    dut._log.info(f"UART Data: {data}")
    assert data == b"kianv"


@cocotb.test()
async def test_spi(dut):
    dut._log.info("start")
    dut.test_sel.value = 0
    clock = Clock(dut.clk, 100, unit="ns")
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


@cocotb.test()
async def test_gpio(dut):
    dut._log.info("start")
    dut.test_sel.value = 1
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Wait for the test firmware to start
    await RisingEdge(dut.uo_out7)
    for expected_val in [0x80, 0x00, 0x85, 0x12, 0x94, 0x17]:
        dut._log.info(
            f"GPIO Data: {dut.uo_out.value.to_unsigned():#X} (expected {expected_val:#X})"
        )
        assert dut.uo_out.value == expected_val
        await dut.uo_out7.value_change
