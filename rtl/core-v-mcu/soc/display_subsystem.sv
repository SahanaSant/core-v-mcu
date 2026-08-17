// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// CORE-V XBAR adapter for the complete memory-mapped display data path.
module display_subsystem #(
    parameter logic [31:0] BASE_ADDR    = 32'h1A40_0000,
    parameter int unsigned FRAME_WIDTH  = 320,
    parameter int unsigned FRAME_HEIGHT = 200,
    parameter int unsigned FRAME_BYTES  = FRAME_WIDTH * FRAME_HEIGHT,
    parameter int unsigned PIXEL_ADDR_WIDTH = $clog2(FRAME_BYTES),
    parameter int unsigned SPI_CLK_DIV  = 2,
    parameter bit          ST7789_INIT_ENABLE = 1'b1,
    parameter int unsigned DISPLAY_CLK_FREQ_HZ = 50_000_000
) (
    input logic clk_i,
    input logic rst_ni,

    XBAR_TCDM_BUS.Slave tcdm_slave,

    output logic spi_cs_no,
    output logic spi_sclk_o,
    output logic spi_mosi_o,
    output logic display_reset_no,
    output logic display_im0_o,
    output logic display_im2_o
);

  display_subsystem_core #(
      .BASE_ADDR       (BASE_ADDR),
      .FRAME_WIDTH     (FRAME_WIDTH),
      .FRAME_HEIGHT    (FRAME_HEIGHT),
      .FRAME_BYTES     (FRAME_BYTES),
      .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH),
      .SPI_CLK_DIV     (SPI_CLK_DIV),
      .ST7789_INIT_ENABLE(ST7789_INIT_ENABLE),
      .DISPLAY_CLK_FREQ_HZ(DISPLAY_CLK_FREQ_HZ)
  ) i_display_subsystem_core (
      .clk_i,
      .rst_ni,
      .tcdm_req_i    (tcdm_slave.req),
      .tcdm_add_i    (tcdm_slave.add),
      .tcdm_wen_i    (tcdm_slave.wen),
      .tcdm_wdata_i  (tcdm_slave.wdata),
      .tcdm_be_i     (tcdm_slave.be),
      .tcdm_gnt_o    (tcdm_slave.gnt),
      .tcdm_r_opc_o  (tcdm_slave.r_opc),
      .tcdm_r_rdata_o(tcdm_slave.r_rdata),
      .tcdm_r_valid_o(tcdm_slave.r_valid),
      .spi_cs_no,
      .spi_sclk_o,
      .spi_mosi_o,
      .display_reset_no,
      .display_im0_o,
      .display_im2_o
  );

endmodule
