// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module display_tcdm_slave #(
    parameter logic [31:0] BASE_ADDR    = 32'h1A40_0000,
    parameter int unsigned FRAME_WIDTH  = 320,
    parameter int unsigned FRAME_HEIGHT = 200,
    parameter int unsigned FRAME_BYTES  = FRAME_WIDTH * FRAME_HEIGHT,
    parameter int unsigned PIXEL_ADDR_WIDTH = $clog2(FRAME_BYTES)
) (
    input logic clk_i,
    input logic rst_ni,

    XBAR_TCDM_BUS.Slave tcdm_slave,

    input  logic                        display_pixel_req_i,
    input  logic [PIXEL_ADDR_WIDTH-1:0] display_pixel_addr_i,
    output logic [7:0]                  display_pixel_o,

    input  logic        display_palette_req_i,
    input  logic [7:0]  display_palette_index_i,
    output logic [15:0] display_color_o,

    output logic display_enable_o,
    output logic frame_start_o,
    input  logic display_busy_i,
    input  logic display_done_i
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
      .tcdm_req_i              (tcdm_slave.req),
      .tcdm_add_i              (tcdm_slave.add),
      .tcdm_wen_i              (tcdm_slave.wen),
      .tcdm_wdata_i            (tcdm_slave.wdata),
      .tcdm_be_i               (tcdm_slave.be),
      .tcdm_gnt_o              (tcdm_slave.gnt),
      .tcdm_r_opc_o            (tcdm_slave.r_opc),
      .tcdm_r_rdata_o          (tcdm_slave.r_rdata),
      .tcdm_r_valid_o          (tcdm_slave.r_valid),
      .display_pixel_req_i,
      .display_pixel_addr_i,
      .display_pixel_o,
      .display_palette_req_i,
      .display_palette_index_i,
      .display_color_o,
      .display_enable_o,
      .frame_start_o,
      .display_busy_i,
      .display_done_i
  );

endmodule
