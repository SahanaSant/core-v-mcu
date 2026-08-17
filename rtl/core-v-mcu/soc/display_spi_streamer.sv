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

  typedef enum logic [3:0] {
    IDLE,
    REQUEST_PIXEL,
    WAIT_PIXEL,
    WAIT_PALETTE,
    LATCH_PIXEL,
    SEND_MEMORY_WRITE,
    WAIT_MEMORY_WRITE,
    SEND_HIGH_BYTE,
    WAIT_HIGH_BYTE,
    SEND_LOW_BYTE,
    WAIT_LOW_BYTE
  } state_e;

  state_e state_q;

  logic [PIXEL_ADDR_WIDTH-1:0] pixel_addr_q;
  logic [15:0]                 pixel_color_q;
  logic                        byte_start;
  logic [7:0]                  byte_data;
  logic                        byte_dc;
  logic                        byte_keep_cs;
  logic                        byte_ready;
  logic                        byte_done;

  assign busy_o          = state_q != IDLE;
  assign pixel_req_o     = state_q == REQUEST_PIXEL;
  assign pixel_addr_o    = pixel_addr_q;
  assign palette_req_o   = state_q == WAIT_PIXEL;
  assign palette_index_o = pixel_i;

  always_comb begin
    byte_start   = 1'b0;
    byte_data    = '0;
    byte_dc      = 1'b1;
    byte_keep_cs = 1'b1;

    unique case (state_q)
      SEND_MEMORY_WRITE: begin
        byte_start = byte_ready;
        byte_data  = 8'h2C;
        byte_dc    = 1'b0;
      end
      SEND_HIGH_BYTE: begin
        byte_start = byte_ready;
        byte_data  = pixel_color_q[15:8];
      end
      SEND_LOW_BYTE: begin
        byte_start   = byte_ready;
        byte_data    = pixel_color_q[7:0];
        byte_keep_cs = pixel_addr_q != FRAME_PIXELS - 1;
      end
      default: begin
      end
    endcase
  end

  display_spi_byte_tx #(
      .SPI_CLK_DIV(SPI_CLK_DIV)
  ) i_display_spi_byte_tx (
      .clk_i,
      .rst_ni,
      .start_i  (byte_start),
      .data_i   (byte_data),
      .dc_i     (byte_dc),
      .keep_cs_i(byte_keep_cs),
      .ready_o  (byte_ready),
      .busy_o   (),
      .done_o   (byte_done),
      .spi_cs_no,
      .spi_sclk_o,
      .spi_mosi_o
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q       <= IDLE;
      pixel_addr_q  <= '0;
      pixel_color_q <= '0;
      done_o        <= 1'b0;
    end else begin
      done_o <= 1'b0;

      unique case (state_q)
        IDLE: begin
          if (frame_start_i && display_enable_i) begin
            pixel_addr_q <= '0;
            state_q      <= SEND_MEMORY_WRITE;
          end
        end

        SEND_MEMORY_WRITE: begin
          if (byte_ready) state_q <= WAIT_MEMORY_WRITE;
        end

        WAIT_MEMORY_WRITE: begin
          if (byte_done) state_q <= REQUEST_PIXEL;
        end

        REQUEST_PIXEL: begin
          state_q <= WAIT_PIXEL;
        end

        WAIT_PIXEL: begin
          state_q <= WAIT_PALETTE;
        end

        WAIT_PALETTE: begin
          state_q <= LATCH_PIXEL;
        end

        LATCH_PIXEL: begin
          pixel_color_q <= palette_color_i;
          state_q       <= SEND_HIGH_BYTE;
        end

        SEND_HIGH_BYTE: begin
          if (byte_ready) state_q <= WAIT_HIGH_BYTE;
        end

        WAIT_HIGH_BYTE: begin
          if (byte_done) state_q <= SEND_LOW_BYTE;
        end

        SEND_LOW_BYTE: begin
          if (byte_ready) state_q <= WAIT_LOW_BYTE;
        end

        WAIT_LOW_BYTE: begin
          if (byte_done) begin
            if (pixel_addr_q == FRAME_PIXELS - 1) begin
              done_o  <= 1'b1;
              state_q <= IDLE;
            end else begin
              pixel_addr_q <= pixel_addr_q + 1'b1;
              state_q      <= REQUEST_PIXEL;
            end
          end
        end

        default: begin
          state_q <= IDLE;
        end
      endcase
    end
  end

endmodule
