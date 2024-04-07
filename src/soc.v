/*
 *  kianv.v - RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
`include "defines_soc.vh"
/* verilator lint_off PINCONNECTEMPTY */
/* verilator lint_off UNUSEDSIGNAL */
module soc (
    input  wire       clk_osc,
    output wire       uart_tx,
    input  wire       uart_rx,
    output wire [6:0] led,
    output wire [2:0] ce,
    output wire       sclk,

    input wire sio0_si_mosi_i,
    input wire sio1_so_miso_i,
    input wire sio2_i,
    input wire sio3_i,

    output wire sio0_si_mosi_o,
    output wire sio1_so_miso_o,
    output wire sio2_o,
    output wire sio3_o,

    output wire [3:0] sio_oe,

    input wire rst_n
);

  wire clk;

  wire [31:0] PC;



  assign led  = PC[16+:7];

  assign clk  = clk_osc;

  localparam BYTE_ADDRESS_LEN = 32;
  localparam BYTES_PER_BLOCK = 4;
  localparam DATA_LEN = 32;
  localparam BLOCK_ADDRESS_LEN = BYTE_ADDRESS_LEN - $clog2(BYTES_PER_BLOCK);

  localparam BRAM_ADDR_WIDTH = $clog2(`BRAM_WORDS);

  //////////////////////////////////////////////////////////////////////////////
  /* SYSCON */

  wire is_valid_reboot_addr = (cpu_mem_addr == `REBOOT_ADDR);
  wire is_valid_reboot_data = (cpu_mem_wdata[15:0] == `REBOOT_DATA);

  wire is_reboot_valid = cpu_mem_valid && is_valid_reboot_addr && is_valid_reboot_data && wr;

  // reset
  reg [3:0] rst_cnt;
  wire resetn = rst_cnt[3];

  always @(posedge clk) begin
    if (!rst_n || is_reboot_valid) rst_cnt <= 0;
    else rst_cnt <= rst_cnt + {3'b0, !resetn};
  end

  // cpu
  wire                      [31:0]                                           pc;
  wire                      [ 5:0]                                           ctrl_state;

  wire                                                                       cpu_mem_ready;
  wire                                                                       cpu_mem_valid;

  wire                      [ 3:0]                                           cpu_mem_wstrb;
  wire                      [31:0]                                           cpu_mem_addr;
  wire                      [31:0]                                           cpu_mem_wdata;
  wire                      [31:0]                                           cpu_mem_rdata;

  wire                      [31:0]                                           bram_rdata;
  reg                                                                        bram_ready;
  wire                                                                       bram_valid;

  // uart
  wire                                                                       uart_tx_valid;
  reg                                                                        uart_tx_ready;
  // uart
  wire                                                                       uart_rx_valid;
  reg                                                                        uart_rx_ready;

  // spi flash memory
  wire                      [31:0]                                           spi_nor_mem_data;
  wire                                                                       spi_nor_mem_valid;

  // divider
  wire                                                                       div_valid;
  reg                                                                        div_ready;

  // RISC-V is byte-addressable, alignment memory devices word organized
  // memory interface
  wire wr = |cpu_mem_wstrb;
  wire rd = ~wr;

  wire                      [29:0] word_aligned_addr = {cpu_mem_addr[31:2]};

  // cpu_freq
  reg                       [31:0]                                           div_reg;
  assign div_valid = !div_ready && cpu_mem_valid && (cpu_mem_addr == `DIV_ADDR);  // && !wr;
  always @(posedge clk) div_ready <= !resetn ? 1'b0 : div_valid;
  always @(posedge clk) begin
    if (!resetn) begin
      div_reg <= 0;
    end else begin
      if (div_valid && wr) div_reg <= cpu_mem_wdata;
    end
  end
  /////////////////////////////////////////////////////////////////////////////

  // SPI nor flash
  assign spi_nor_mem_valid = !qqspi_mem_ready && cpu_mem_valid &&
           (cpu_mem_addr >= `SPI_NOR_MEM_ADDR_START && cpu_mem_addr < `SPI_NOR_MEM_ADDR_END) && !wr;

  // PSRAM
  wire mem_sdram_valid;

  wire is_sdram = (cpu_mem_addr >= `SDRAM_MEM_ADDR_START && cpu_mem_addr < `SDRAM_MEM_ADDR_END);
  assign mem_sdram_valid = !qqspi_mem_ready && cpu_mem_valid && is_sdram;

  /////////////////////////////////////////////////////////////////////////////

  wire [31:0] qqspi_mem_rdata;
  wire qqspi_mem_ready;

  qqspi #(.CHIP_SELECTS(3)) qqspi_I (
      .addr({1'b0, word_aligned_addr[21:0]}),
      .wdata(cpu_mem_wdata),
      .rdata(qqspi_mem_rdata),
      .wstrb(cpu_mem_wstrb),
      .ready(qqspi_mem_ready),
      .valid(spi_nor_mem_valid | mem_sdram_valid),
      .QUAD_MODE(1'b1),
      .PSRAM_SPIFLASH(mem_sdram_valid),

      .sclk(sclk),

      .sio0_si_mosi_i(sio0_si_mosi_i),
      .sio1_so_miso_i(sio1_so_miso_i),
      .sio2_i        (sio2_i),
      .sio3_i        (sio3_i),

      .sio0_si_mosi_o(sio0_si_mosi_o),
      .sio1_so_miso_o(sio1_so_miso_o),
      .sio2_o        (sio2_o),
      .sio3_o        (sio3_o),
      .sio_oe        (sio_oe),

      .ce_ctrl({1'b0, mem_sdram_valid, spi_nor_mem_valid}),
      .ce(ce),

      .clk   (clk),
      .resetn(resetn)
  );

  /////////////////////////////////////////////////////////////////////////////

  wire uart_tx_valid_wr;

  // I have changed to blocked tx
  assign uart_tx_valid = ~uart_tx_ready && cpu_mem_valid && cpu_mem_addr == `UART_TX_ADDR;
  //assign uart_tx_valid = ~uart_tx_rdy && cpu_mem_valid && cpu_mem_addr == `UART_TX_ADDR; // blocking
  assign uart_tx_valid_wr = wr && uart_tx_valid;
  always @(posedge clk) uart_tx_ready <= !resetn ? 1'b0 : uart_tx_valid_wr;

  wire uart_tx_busy;
  wire uart_tx_rdy;

  tx_uart tx_uart_i (
      .clk    (clk),
      .resetn (resetn),
      .valid  (uart_tx_valid_wr),
      .tx_data(cpu_mem_wdata[7:0]),
      .div    (div_reg[15:0]),
      .tx_out (uart_tx),
      .ready  (uart_tx_rdy),
      .busy   (uart_tx_busy)
  );

  /////////////////////////////////////////////////////////////////////////////
  wire uart_lsr_valid_rd = ~uart_lsr_rdy && rd && cpu_mem_valid && cpu_mem_addr == `UART_LSR_ADDR;
  reg uart_lsr_rdy;
  always @(posedge clk) uart_lsr_rdy <= !resetn ? 1'b0 : uart_lsr_valid_rd;

  /////////////////////////////////////////////////////////////////////////////

  wire uart_rx_valid_rd;
  wire [31:0] rx_uart_data;

  assign uart_rx_valid = ~uart_rx_ready && cpu_mem_valid && cpu_mem_addr == `UART_RX_ADDR;
  assign uart_rx_valid_rd = rd && uart_rx_valid;

  always @(posedge clk) begin
    uart_rx_ready <= !resetn ? 1'b0 : uart_rx_valid_rd;
  end

  wire rx_uart_rdy = uart_rx_ready;
  rx_uart rx_uart_i (
      .clk    (clk),
      .resetn (resetn),
      .rx_in  (uart_rx),
      .div    (div_reg[15:0]),
      .error  (),
      .data_rd(rx_uart_rdy),    // pop
      .data   (rx_uart_data)
  );

  /////////////////////////////////////////////////////////////////////////////

  wire IRQ3;
  wire IRQ7;
  wire clint_valid;
  wire clint_ready;
  wire [31:0] clint_rdata;

  clint clint_I (
      .clk     (clk),
      .resetn  (resetn),
      .valid   (cpu_mem_valid),
      .addr    (cpu_mem_addr),
      .wmask   (cpu_mem_wstrb),
      .wdata   (cpu_mem_wdata),
      .rdata   (clint_rdata),
      .div     (div_reg[31:16]),
      .IRQ3    (IRQ3),
      .IRQ7    (IRQ7),
      .is_valid(clint_valid),
      .ready   (clint_ready)
  );

  /////////////////////////////////////////////////////////////////////////////
  kianv_harris_mc_edition #(
      .RESET_ADDR(`RESET_ADDR)
  ) kianv_I (
      .clk         (clk),
      .resetn      (resetn),
      .mem_ready   (cpu_mem_ready),
      .mem_valid   (cpu_mem_valid),
      .mem_wstrb   (cpu_mem_wstrb),
      .mem_addr    (cpu_mem_addr),
      .mem_wdata   (cpu_mem_wdata),
      .mem_rdata   (cpu_mem_rdata),
      .access_fault(access_fault),
      .IRQ3        (IRQ3),
      .IRQ7        (IRQ7),
      .PC          (PC)
  );

  /////////////////////////////////////////////////////////////////////////////
  wire is_io = (cpu_mem_addr >= 32'h10_000_000 && cpu_mem_addr <= 32'h12_000_000);
  wire unmatched_io = !(uart_lsr_valid_rd || uart_tx_valid || uart_rx_valid || clint_valid || div_valid);

  wire access_fault = cpu_mem_valid & (!is_io || !is_sdram);

  reg io_ready;
  reg [31:0] io_rdata;
  reg [7:0] byteswaiting;

  always @(*) begin
    io_rdata = 0;
    io_ready = 1'b0;
    byteswaiting = 0;
    if (is_io) begin
      if (uart_lsr_rdy) begin
        byteswaiting = {1'b0, !uart_tx_busy, !uart_tx_busy, 1'b0, 3'b0, !(&rx_uart_data)};
        io_rdata = {16'b0, byteswaiting, 8'b0};
        io_ready = 1'b1;
      end else if (uart_rx_ready) begin
        io_rdata = rx_uart_data;
        io_ready = 1'b1;
      end else if (uart_tx_ready) begin
        io_rdata = 0;
        io_ready = 1'b1;
        //io_ready = uart_tx_rdy; // blocking
      end else if (clint_ready) begin
        io_rdata = clint_rdata;
        io_ready = 1'b1;
      end else if (div_ready) begin
        io_rdata = div_reg;
        io_ready = 1'b1;
      end else if (unmatched_io) begin
        io_rdata = 0;
        io_ready = 1'b1;
      end
    end
  end

  /////////////////////////////////////////////////////////////////////////////
  assign cpu_mem_ready = qqspi_mem_ready || io_ready;

  assign cpu_mem_rdata = qqspi_mem_ready ? qqspi_mem_rdata : io_ready ? io_rdata : 32'h0000_0000;

endmodule
/* verilator lint_on PINCONNECTEMPTY */
/* verilator lint_on UNUSEDSIGNAL */
