// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module display_framebuffer #(
    parameter int unsigned FRAME_WIDTH  = 320,
    parameter int unsigned FRAME_HEIGHT = 200,
    parameter int unsigned FRAME_BYTES  = FRAME_WIDTH * FRAME_HEIGHT,
    parameter int unsigned CPU_WORDS    = (FRAME_BYTES + 3) / 4,
    parameter int unsigned CPU_ADDR_WIDTH = $clog2(CPU_WORDS),
    parameter int unsigned PIXEL_ADDR_WIDTH = $clog2(FRAME_BYTES)
) (
    input logic clk_i,

    input  logic                      cpu_req_i,
    input  logic                      cpu_write_i,
    input  logic [3:0]                cpu_be_i,
    input  logic [CPU_ADDR_WIDTH-1:0] cpu_addr_i,
    input  logic [31:0]               cpu_wdata_i,
    output logic [31:0]               cpu_rdata_o,

    input  logic                        display_req_i,
    input  logic [PIXEL_ADDR_WIDTH-1:0] display_addr_i,
    output logic [7:0]                  display_rdata_o
);

  (* ram_style = "block" *) logic [31:0] memory [0:CPU_WORDS-1];

  always_ff @(posedge clk_i) begin
    if (cpu_req_i) begin
      cpu_rdata_o <= memory[cpu_addr_i];

      if (cpu_write_i) begin
        if (cpu_be_i[0]) memory[cpu_addr_i][7:0]   <= cpu_wdata_i[7:0];
        if (cpu_be_i[1]) memory[cpu_addr_i][15:8]  <= cpu_wdata_i[15:8];
        if (cpu_be_i[2]) memory[cpu_addr_i][23:16] <= cpu_wdata_i[23:16];
        if (cpu_be_i[3]) memory[cpu_addr_i][31:24] <= cpu_wdata_i[31:24];
      end
    end

    if (display_req_i) begin
      unique case (display_addr_i[1:0])
        2'd0: display_rdata_o <= memory[display_addr_i[PIXEL_ADDR_WIDTH-1:2]][7:0];
        2'd1: display_rdata_o <= memory[display_addr_i[PIXEL_ADDR_WIDTH-1:2]][15:8];
        2'd2: display_rdata_o <= memory[display_addr_i[PIXEL_ADDR_WIDTH-1:2]][23:16];
        default: display_rdata_o <= memory[display_addr_i[PIXEL_ADDR_WIDTH-1:2]][31:24];
      endcase
    end
  end

endmodule
