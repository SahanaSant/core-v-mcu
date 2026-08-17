// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Tool-portable core of the complete memory-mapped display data path. Keeping
// the TCDM signals scalar lets lightweight simulators test the subsystem while
// display_subsystem.sv provides the CORE-V XBAR interface adapter.
module display_subsystem_core #(
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

    input  logic        tcdm_req_i,
    input  logic [31:0] tcdm_add_i,
    input  logic        tcdm_wen_i,
    input  logic [31:0] tcdm_wdata_i,
    input  logic [3:0]  tcdm_be_i,
    output logic        tcdm_gnt_o,
    output logic        tcdm_r_opc_o,
    output logic [31:0] tcdm_r_rdata_o,
    output logic        tcdm_r_valid_o,

    output logic spi_cs_no,
    output logic spi_sclk_o,
    output logic spi_mosi_o,
    output logic display_reset_no,
    output logic display_im0_o,
    output logic display_im2_o
);

  logic                        display_pixel_req;
  logic [PIXEL_ADDR_WIDTH-1:0] display_pixel_addr;
  logic [7:0]                  display_pixel;
  logic                        display_palette_req;
  logic [7:0]                  display_palette_index;
  logic [15:0]                 display_color;
  logic                        display_enable;
  logic                        frame_start;
  logic                        display_busy;
  logic                        display_done;
  logic                        stream_busy;
  logic                        stream_done;
  logic                        display_initialized;
  logic                        init_spi_cs_n;
  logic                        init_spi_sclk;
  logic                        init_spi_mosi;
  logic                        stream_spi_cs_n;
  logic                        stream_spi_sclk;
  logic                        stream_spi_mosi;

  assign display_busy = !display_initialized || stream_busy;
  assign display_done = stream_done;

  // The Newhaven module selects 3-wire SPI when both exposed mode pins are 1.
  assign display_im0_o = 1'b1;
  assign display_im2_o = 1'b1;

  // Initialization owns the shared serial pins until it has completed.
  assign spi_cs_no   = display_initialized ? stream_spi_cs_n : init_spi_cs_n;
  assign spi_sclk_o  = display_initialized ? stream_spi_sclk : init_spi_sclk;
  assign spi_mosi_o  = display_initialized ? stream_spi_mosi : init_spi_mosi;

  display_st7789_init #(
      .ENABLE      (ST7789_INIT_ENABLE),
      .CLK_FREQ_HZ (DISPLAY_CLK_FREQ_HZ),
      .SPI_CLK_DIV (SPI_CLK_DIV),
      .LCD_WIDTH   (320),
      .LCD_HEIGHT  (240),
      .MADCTL_VALUE(8'h20)
  ) i_display_st7789_init (
      .clk_i,
      .rst_ni,
      .initialized_o(display_initialized),
      .busy_o       (),
      .lcd_reset_no (display_reset_no),
      .spi_cs_no    (init_spi_cs_n),
      .spi_sclk_o   (init_spi_sclk),
      .spi_mosi_o   (init_spi_mosi)
  );

  display_tcdm_slave_core #(
      .BASE_ADDR       (BASE_ADDR),
      .FRAME_WIDTH     (FRAME_WIDTH),
      .FRAME_HEIGHT    (FRAME_HEIGHT),
      .FRAME_BYTES     (FRAME_BYTES),
      .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH)
  ) i_display_tcdm_slave_core (
      .clk_i,
      .rst_ni,
      .tcdm_req_i,
      .tcdm_add_i,
      .tcdm_wen_i,
      .tcdm_wdata_i,
      .tcdm_be_i,
      .tcdm_gnt_o,
      .tcdm_r_opc_o,
      .tcdm_r_rdata_o,
      .tcdm_r_valid_o,
      .display_pixel_req_i    (display_pixel_req),
      .display_pixel_addr_i   (display_pixel_addr),
      .display_pixel_o        (display_pixel),
      .display_palette_req_i  (display_palette_req),
      .display_palette_index_i(display_palette_index),
      .display_color_o        (display_color),
      .display_enable_o       (display_enable),
      .frame_start_o          (frame_start),
      .display_busy_i         (display_busy),
      .display_done_i         (display_done)
  );

  display_spi_streamer #(
      .FRAME_PIXELS    (FRAME_BYTES),
      .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH),
      .SPI_CLK_DIV     (SPI_CLK_DIV)
  ) i_display_spi_streamer (
      .clk_i,
      .rst_ni,
      .frame_start_i   (frame_start && display_initialized),
      .display_enable_i(display_enable),
      .busy_o          (stream_busy),
      .done_o          (stream_done),
      .pixel_req_o     (display_pixel_req),
      .pixel_addr_o    (display_pixel_addr),
      .pixel_i         (display_pixel),
      .palette_req_o   (display_palette_req),
      .palette_index_o (display_palette_index),
      .palette_color_i (display_color),
      .spi_cs_no       (stream_spi_cs_n),
      .spi_sclk_o      (stream_spi_sclk),
      .spi_mosi_o      (stream_spi_mosi)
  );

endmodule
