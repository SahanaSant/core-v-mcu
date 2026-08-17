// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Reusable ST7789VI 3-wire SPI transmitter. Every transfer contains the
// command/data indicator followed by one 8-bit payload, MSB first. Chip select
// may remain asserted between 9-bit transfers for command arguments or pixels.
module display_spi_byte_tx #(
    parameter int unsigned SPI_CLK_DIV = 2
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic       start_i,
    input  logic [7:0] data_i,
    input  logic       dc_i,
    input  logic       keep_cs_i,
    output logic       ready_o,
    output logic       busy_o,
    output logic       done_o,

    output logic spi_cs_no,
    output logic spi_sclk_o,
    output logic spi_mosi_o
);

  localparam int unsigned DIV_WIDTH = (SPI_CLK_DIV <= 1) ? 1 : $clog2(SPI_CLK_DIV);

  logic [8:0]           shift_q;
  logic [3:0]           bit_count_q;
  logic [DIV_WIDTH-1:0] divider_q;
  logic                 keep_cs_q;

  assign ready_o = !busy_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shift_q     <= '0;
      bit_count_q <= '0;
      divider_q   <= '0;
      keep_cs_q   <= 1'b0;
      busy_o      <= 1'b0;
      done_o      <= 1'b0;
      spi_cs_no   <= 1'b1;
      spi_sclk_o  <= 1'b0;
      spi_mosi_o  <= 1'b0;
    end else begin
      done_o <= 1'b0;

      if (!busy_o) begin
        spi_sclk_o <= 1'b0;
        divider_q  <= '0;

        if (start_i) begin
          shift_q     <= {dc_i, data_i};
          bit_count_q <= 4'd8;
          keep_cs_q   <= keep_cs_i;
          busy_o      <= 1'b1;
          spi_cs_no   <= 1'b0;
          spi_mosi_o  <= dc_i;
        end
      end else if (divider_q == SPI_CLK_DIV - 1) begin
        divider_q <= '0;

        if (!spi_sclk_o) begin
          // SPI mode 0: the receiver samples MOSI on this rising edge.
          spi_sclk_o <= 1'b1;
        end else begin
          // Change MOSI only on falling edges.
          spi_sclk_o <= 1'b0;

          if (bit_count_q == 0) begin
            busy_o    <= 1'b0;
            done_o    <= 1'b1;
            spi_cs_no <= keep_cs_q ? 1'b0 : 1'b1;
          end else begin
            shift_q     <= {shift_q[7:0], 1'b0};
            bit_count_q <= bit_count_q - 1'b1;
            spi_mosi_o  <= shift_q[7];
          end
        end
      end else begin
        divider_q <= divider_q + 1'b1;
      end
    end
  end

endmodule
