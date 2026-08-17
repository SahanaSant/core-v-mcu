// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module display_palette (
    input logic clk_i,

    input  logic        cpu_req_i,
    input  logic        cpu_write_i,
    input  logic [3:0]  cpu_be_i,
    input  logic [6:0]  cpu_addr_i,
    input  logic [31:0] cpu_wdata_i,
    output logic [31:0] cpu_rdata_o,

    input  logic        display_req_i,
    input  logic [7:0]  display_index_i,
    output logic [15:0] display_color_o
);

  (* ram_style = "distributed" *) logic [31:0] palette [0:127];

  always_ff @(posedge clk_i) begin
    if (cpu_req_i) begin
      cpu_rdata_o <= palette[cpu_addr_i];

      if (cpu_write_i) begin
        if (cpu_be_i[0]) palette[cpu_addr_i][7:0]   <= cpu_wdata_i[7:0];
        if (cpu_be_i[1]) palette[cpu_addr_i][15:8]  <= cpu_wdata_i[15:8];
        if (cpu_be_i[2]) palette[cpu_addr_i][23:16] <= cpu_wdata_i[23:16];
        if (cpu_be_i[3]) palette[cpu_addr_i][31:24] <= cpu_wdata_i[31:24];
      end
    end

    if (display_req_i) begin
      if (display_index_i[0]) begin
        display_color_o <= palette[display_index_i[7:1]][31:16];
      end else begin
        display_color_o <= palette[display_index_i[7:1]][15:0];
      end
    end
  end

endmodule
