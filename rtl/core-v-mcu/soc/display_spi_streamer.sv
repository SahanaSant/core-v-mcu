// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module display_spi_streamer #(
    parameter int unsigned FRAME_PIXELS     = 320 * 200,
    parameter int unsigned PIXEL_ADDR_WIDTH = $clog2(FRAME_PIXELS),
    parameter int unsigned SPI_CLK_DIV      = 2
) (
    input logic clk_i,
    input logic rst_ni,

    input logic frame_start_i,
    input logic display_enable_i,
    output logic busy_o,
    output logic done_o,

    output logic                        pixel_req_o,
    output logic [PIXEL_ADDR_WIDTH-1:0] pixel_addr_o,
    input  logic [7:0]                  pixel_i,

    output logic        palette_req_o,
    output logic [7:0]  palette_index_o,
    input  logic [15:0] palette_color_i,

    output logic spi_cs_no,
    output logic spi_sclk_o,
    output logic spi_mosi_o
);

  localparam int unsigned DIV_WIDTH = (SPI_CLK_DIV <= 1) ? 1 : $clog2(SPI_CLK_DIV);

  typedef enum logic [2:0] {
    IDLE,
    REQUEST_PIXEL,
    WAIT_PIXEL,
    WAIT_PALETTE,
    LOAD_PIXEL,
    SHIFT_PIXEL
  } state_e;

  state_e state_q;

  logic [PIXEL_ADDR_WIDTH-1:0] pixel_addr_q;
  logic [15:0]                 shift_q;
  logic [4:0]                  bit_count_q;
  logic [DIV_WIDTH-1:0]        divider_q;

  assign busy_o          = state_q != IDLE;
  assign pixel_req_o     = state_q == REQUEST_PIXEL;
  assign pixel_addr_o    = pixel_addr_q;
  assign palette_req_o   = state_q == WAIT_PIXEL;
  assign palette_index_o = pixel_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q      <= IDLE;
      pixel_addr_q <= '0;
      shift_q      <= '0;
      bit_count_q  <= '0;
      divider_q    <= '0;
      done_o       <= 1'b0;
      spi_cs_no    <= 1'b1;
      spi_sclk_o   <= 1'b0;
      spi_mosi_o   <= 1'b0;
    end else begin
      done_o <= 1'b0;

      unique case (state_q)
        IDLE: begin
          spi_cs_no  <= 1'b1;
          spi_sclk_o <= 1'b0;
          divider_q  <= '0;

          if (frame_start_i && display_enable_i) begin
            pixel_addr_q <= '0;
            spi_cs_no    <= 1'b0;
            state_q      <= REQUEST_PIXEL;
          end
        end

        REQUEST_PIXEL: begin
          state_q <= WAIT_PIXEL;
        end

        WAIT_PIXEL: begin
          state_q <= WAIT_PALETTE;
        end

        WAIT_PALETTE: begin
          state_q <= LOAD_PIXEL;
        end

        LOAD_PIXEL: begin
          shift_q     <= palette_color_i;
          bit_count_q <= 5'd15;
          divider_q   <= '0;
          spi_mosi_o  <= palette_color_i[15];
          state_q     <= SHIFT_PIXEL;
        end

        SHIFT_PIXEL: begin
          if (divider_q == SPI_CLK_DIV - 1) begin
            divider_q <= '0;

            if (!spi_sclk_o) begin
              // SPI mode 0: the receiver samples MOSI on this rising edge.
              spi_sclk_o <= 1'b1;
            end else begin
              // Change MOSI only on falling edges.
              spi_sclk_o <= 1'b0;

              if (bit_count_q == 0) begin
                if (pixel_addr_q == FRAME_PIXELS - 1) begin
                  spi_cs_no <= 1'b1;
                  done_o    <= 1'b1;
                  state_q   <= IDLE;
                end else begin
                  pixel_addr_q <= pixel_addr_q + 1'b1;
                  state_q      <= REQUEST_PIXEL;
                end
              end else begin
                shift_q     <= {shift_q[14:0], 1'b0};
                bit_count_q <= bit_count_q - 1'b1;
                spi_mosi_o  <= shift_q[14];
              end
            end
          end else begin
            divider_q <= divider_q + 1'b1;
          end
        end

        default: begin
          state_q <= IDLE;
        end
      endcase
    end
  end

endmodule
