import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotbext.uart import UartSource, UartSink

@cocotb.test()
async def test_uart(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    uart_source = UartSource(dut.uart_rx, baud=115200, bits=8)
    uart_sink = UartSink(dut.uart_tx, baud=115200, bits=8)

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
        
    await ClockCycles(dut.clk, 20000*6)

    expected_str = b"Hello UART\n"
    data = uart_sink.read_nowait(len(expected_str))
    dut._log.info(f"UART Data: {data}")
    assert data == expected_str

    # The code should convert these to lowercase and echo them
    await uart_source.write(b'Q')
    await ClockCycles(dut.clk, 2500)
    await uart_source.write(b'A')
    await ClockCycles(dut.clk, 4000)

    data = uart_sink.read_nowait(2)
    dut._log.info(f"UART Data: {data}")
    assert data == b"qa"
