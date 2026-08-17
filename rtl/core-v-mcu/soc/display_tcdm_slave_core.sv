// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module display_tcdm_slave_core #(
    parameter logic [31:0] BASE_ADDR    = 32'h1A40_0000,
    parameter int unsigned FRAME_WIDTH  = 320,
    parameter int unsigned FRAME_HEIGHT = 200,
    parameter int unsigned FRAME_BYTES  = FRAME_WIDTH * FRAME_HEIGHT,
    parameter int unsigned PIXEL_ADDR_WIDTH = $clog2(FRAME_BYTES)
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

  localparam logic [31:0] CONTROL_OFFSET       = 32'h0000_0000;
  localparam logic [31:0] STATUS_OFFSET        = 32'h0000_0004;
  localparam logic [31:0] FRAME_COUNTER_OFFSET = 32'h0000_0008;
  localparam logic [31:0] SCRATCH_OFFSET       = 32'h0000_000C;
  localparam logic [31:0] PALETTE_OFFSET       = 32'h0000_1000;
  localparam logic [31:0] PALETTE_BYTES        = 32'h0000_0200;
  localparam logic [31:0] FRAMEBUFFER_OFFSET   = 32'h0001_0000;

  localparam int unsigned FRAME_WORDS = (FRAME_BYTES + 3) / 4;
  localparam int unsigned FRAME_WORD_ADDR_WIDTH = $clog2(FRAME_WORDS);
  localparam int unsigned PALETTE_WORD_ADDR_WIDTH = 7;

  typedef enum logic [1:0] {
    RESPONSE_REG,
    RESPONSE_PALETTE,
    RESPONSE_FRAMEBUFFER,
    RESPONSE_ERROR
  } response_sel_e;

  logic [31:0] address_offset;
  logic        register_access;
  logic        palette_access;
  logic        framebuffer_access;
  logic        valid_access;
  logic        write_request;

  logic [31:0] control_q;
  logic [31:0] scratch_q;
  logic [31:0] frame_counter_q;
  logic        frame_done_q;

  response_sel_e response_sel_q;
  logic          response_valid_q;
  logic          response_error_q;
  logic [31:0]   register_rdata_q;

  logic palette_cpu_req;
  logic palette_cpu_write;
  logic [PALETTE_WORD_ADDR_WIDTH-1:0] palette_cpu_addr;
  logic [31:0] palette_cpu_rdata;

  logic framebuffer_cpu_req;
  logic framebuffer_cpu_write;
  logic [FRAME_WORD_ADDR_WIDTH-1:0] framebuffer_cpu_addr;
  logic [31:0] framebuffer_cpu_rdata;

  assign address_offset = tcdm_add_i - BASE_ADDR;

  assign register_access =
      (address_offset == CONTROL_OFFSET) ||
      (address_offset == STATUS_OFFSET) ||
      (address_offset == FRAME_COUNTER_OFFSET) ||
      (address_offset == SCRATCH_OFFSET);
  assign palette_access =
      (address_offset >= PALETTE_OFFSET) &&
      (address_offset < (PALETTE_OFFSET + PALETTE_BYTES));
  assign framebuffer_access =
      (address_offset >= FRAMEBUFFER_OFFSET) &&
      (address_offset < (FRAMEBUFFER_OFFSET + FRAME_BYTES));
  assign valid_access = register_access || palette_access || framebuffer_access;
  assign write_request = tcdm_req_i && !tcdm_wen_i;

  assign palette_cpu_req = tcdm_req_i && palette_access;
  assign palette_cpu_write = palette_cpu_req && !tcdm_wen_i;
  assign palette_cpu_addr = (address_offset - PALETTE_OFFSET) >> 2;

  assign framebuffer_cpu_req = tcdm_req_i && framebuffer_access;
  assign framebuffer_cpu_write = framebuffer_cpu_req && !tcdm_wen_i;
  assign framebuffer_cpu_addr = (address_offset - FRAMEBUFFER_OFFSET) >> 2;

  assign tcdm_gnt_o = tcdm_req_i;
  assign tcdm_r_valid_o = response_valid_q;
  assign tcdm_r_opc_o = response_error_q;

  always_comb begin
    unique case (response_sel_q)
      RESPONSE_REG:         tcdm_r_rdata_o = register_rdata_q;
      RESPONSE_PALETTE:     tcdm_r_rdata_o = palette_cpu_rdata;
      RESPONSE_FRAMEBUFFER: tcdm_r_rdata_o = framebuffer_cpu_rdata;
      default:              tcdm_r_rdata_o = 32'hBADACCE5;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      control_q       <= '0;
      scratch_q       <= '0;
      frame_counter_q <= '0;
      frame_done_q    <= 1'b0;
      frame_start_o   <= 1'b0;
    end else begin
      frame_start_o <= 1'b0;

      if (display_done_i) begin
        frame_done_q    <= 1'b1;
        frame_counter_q <= frame_counter_q + 1'b1;
      end

      if (write_request && register_access) begin
        unique case (address_offset)
          CONTROL_OFFSET: begin
            if (tcdm_be_i[0]) begin
              control_q[0] <= tcdm_wdata_i[0];
              if (tcdm_wdata_i[1]) begin
                frame_start_o <= 1'b1;
                frame_done_q  <= 1'b0;
              end
            end
          end
          SCRATCH_OFFSET: begin
            if (tcdm_be_i[0]) scratch_q[7:0]   <= tcdm_wdata_i[7:0];
            if (tcdm_be_i[1]) scratch_q[15:8]  <= tcdm_wdata_i[15:8];
            if (tcdm_be_i[2]) scratch_q[23:16] <= tcdm_wdata_i[23:16];
            if (tcdm_be_i[3]) scratch_q[31:24] <= tcdm_wdata_i[31:24];
          end
          default: begin
          end
        endcase
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      response_sel_q   <= RESPONSE_ERROR;
      response_valid_q <= 1'b0;
      response_error_q <= 1'b0;
      register_rdata_q <= '0;
    end else begin
      response_valid_q <= tcdm_req_i;
      response_error_q <= tcdm_req_i && !valid_access;

      if (tcdm_req_i) begin
        if (register_access) begin
          response_sel_q <= RESPONSE_REG;
          unique case (address_offset)
            CONTROL_OFFSET:       register_rdata_q <= control_q;
            STATUS_OFFSET:        register_rdata_q <= {30'b0, frame_done_q, display_busy_i};
            FRAME_COUNTER_OFFSET: register_rdata_q <= frame_counter_q;
            SCRATCH_OFFSET:       register_rdata_q <= scratch_q;
            default:              register_rdata_q <= '0;
          endcase
        end else if (palette_access) begin
          response_sel_q <= RESPONSE_PALETTE;
        end else if (framebuffer_access) begin
          response_sel_q <= RESPONSE_FRAMEBUFFER;
        end else begin
          response_sel_q   <= RESPONSE_ERROR;
          register_rdata_q <= 32'hBADACCE5;
        end
      end
    end
  end

  assign display_enable_o = control_q[0];

  display_palette i_display_palette (
      .clk_i,
      .cpu_req_i      (palette_cpu_req),
      .cpu_write_i    (palette_cpu_write),
      .cpu_be_i       (tcdm_be_i),
      .cpu_addr_i     (palette_cpu_addr),
      .cpu_wdata_i    (tcdm_wdata_i),
      .cpu_rdata_o    (palette_cpu_rdata),
      .display_req_i  (display_palette_req_i),
      .display_index_i(display_palette_index_i),
      .display_color_o(display_color_o)
  );

  display_framebuffer #(
      .FRAME_WIDTH     (FRAME_WIDTH),
      .FRAME_HEIGHT    (FRAME_HEIGHT),
      .FRAME_BYTES     (FRAME_BYTES),
      .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH)
  ) i_display_framebuffer (
      .clk_i,
      .cpu_req_i      (framebuffer_cpu_req),
      .cpu_write_i    (framebuffer_cpu_write),
      .cpu_be_i       (tcdm_be_i),
      .cpu_addr_i     (framebuffer_cpu_addr),
      .cpu_wdata_i    (tcdm_wdata_i),
      .cpu_rdata_o    (framebuffer_cpu_rdata),
      .display_req_i  (display_pixel_req_i),
      .display_addr_i (display_pixel_addr_i),
      .display_rdata_o(display_pixel_o)
  );

endmodule
