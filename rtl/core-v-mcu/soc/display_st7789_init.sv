// Copyright 2026 Schulich on a Chip
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Power-on initialization for the Newhaven NHD-2.4-240320AF-CTXP display.
// The command values follow Newhaven's ST7789VI example; MADCTL and the
// address window are adapted for a 320x240 landscape RGB framebuffer.
module display_st7789_init #(
    parameter bit          ENABLE         = 1'b1,
    parameter int unsigned CLK_FREQ_HZ    = 50_000_000,
    parameter int unsigned SPI_CLK_DIV    = 2,
    parameter int unsigned LCD_WIDTH      = 320,
    parameter int unsigned LCD_HEIGHT     = 240,
    parameter logic [7:0]  MADCTL_VALUE   = 8'h20
) (
    input logic clk_i,
    input logic rst_ni,

    output logic initialized_o,
    output logic busy_o,
    output logic lcd_reset_no,

    output logic spi_cs_no,
    output logic spi_sclk_o,
    output logic spi_mosi_o
);

  localparam int unsigned CYCLES_PER_MS = (CLK_FREQ_HZ + 999) / 1000;
  localparam int unsigned RESET_LOW_CYCLES  = CYCLES_PER_MS * 250;
  localparam int unsigned RESET_HIGH_CYCLES = CYCLES_PER_MS * 250;
  localparam int unsigned SLEEP_OUT_CYCLES  = CYCLES_PER_MS * 100;
  localparam int unsigned WINDOW_WAIT_CYCLES = CYCLES_PER_MS * 10;
  localparam int unsigned FINAL_WAIT_CYCLES = CYCLES_PER_MS * 10;
  localparam int unsigned INIT_WORDS = 72;
  localparam logic [15:0] LCD_X_END = LCD_WIDTH - 1;
  localparam logic [15:0] LCD_Y_END = LCD_HEIGHT - 1;

  typedef enum logic [2:0] {
    RESET_LOW,
    RESET_HIGH,
    SEND_WORD,
    WAIT_WORD,
    WAIT_DELAY,
    COMPLETE
  } state_e;

  state_e      state_q;
  logic [6:0]  word_index_q;
  logic [31:0] delay_count_q;
  logic [31:0] delay_target_q;
  logic        tx_start;
  logic        tx_ready;
  logic        tx_done;
  logic [8:0]  current_word;
  logic [31:0] current_delay;

  function automatic logic [8:0] init_word(input logic [6:0] index);
    begin
      unique case (index)
        0:  init_word = {1'b0, 8'h28};
        1:  init_word = {1'b0, 8'h11};
        2:  init_word = {1'b0, 8'h36};
        3:  init_word = {1'b1, MADCTL_VALUE};
        4:  init_word = {1'b0, 8'h3A};
        5:  init_word = {1'b1, 8'h55};
        6:  init_word = {1'b0, 8'hB2};
        7:  init_word = {1'b1, 8'h0C};
        8:  init_word = {1'b1, 8'h0C};
        9:  init_word = {1'b1, 8'h00};
        10: init_word = {1'b1, 8'h33};
        11: init_word = {1'b1, 8'h33};
        12: init_word = {1'b0, 8'hB7};
        13: init_word = {1'b1, 8'h35};
        14: init_word = {1'b0, 8'hBB};
        15: init_word = {1'b1, 8'h2B};
        16: init_word = {1'b0, 8'hC0};
        17: init_word = {1'b1, 8'h2C};
        18: init_word = {1'b0, 8'hC2};
        19: init_word = {1'b1, 8'h01};
        20: init_word = {1'b1, 8'hFF};
        21: init_word = {1'b0, 8'hC3};
        22: init_word = {1'b1, 8'h11};
        23: init_word = {1'b0, 8'hC4};
        24: init_word = {1'b1, 8'h20};
        25: init_word = {1'b0, 8'hC6};
        26: init_word = {1'b1, 8'h0F};
        27: init_word = {1'b0, 8'hD0};
        28: init_word = {1'b1, 8'hA4};
        29: init_word = {1'b1, 8'hA1};
        30: init_word = {1'b0, 8'hE0};
        31: init_word = {1'b1, 8'hD0};
        32: init_word = {1'b1, 8'h00};
        33: init_word = {1'b1, 8'h05};
        34: init_word = {1'b1, 8'h0E};
        35: init_word = {1'b1, 8'h15};
        36: init_word = {1'b1, 8'h0D};
        37: init_word = {1'b1, 8'h37};
        38: init_word = {1'b1, 8'h43};
        39: init_word = {1'b1, 8'h47};
        40: init_word = {1'b1, 8'h09};
        41: init_word = {1'b1, 8'h15};
        42: init_word = {1'b1, 8'h12};
        43: init_word = {1'b1, 8'h16};
        44: init_word = {1'b1, 8'h19};
        45: init_word = {1'b0, 8'hE1};
        46: init_word = {1'b1, 8'hD0};
        47: init_word = {1'b1, 8'h00};
        48: init_word = {1'b1, 8'h05};
        49: init_word = {1'b1, 8'h0D};
        50: init_word = {1'b1, 8'h0C};
        51: init_word = {1'b1, 8'h06};
        52: init_word = {1'b1, 8'h2D};
        53: init_word = {1'b1, 8'h44};
        54: init_word = {1'b1, 8'h40};
        55: init_word = {1'b1, 8'h0E};
        56: init_word = {1'b1, 8'h1C};
        57: init_word = {1'b1, 8'h18};
        58: init_word = {1'b1, 8'h16};
        59: init_word = {1'b1, 8'h19};
        60: init_word = {1'b0, 8'h2A};
        61: init_word = {1'b1, 8'h00};
        62: init_word = {1'b1, 8'h00};
        63: init_word = {1'b1, LCD_X_END[15:8]};
        64: init_word = {1'b1, LCD_X_END[7:0]};
        65: init_word = {1'b0, 8'h2B};
        66: init_word = {1'b1, 8'h00};
        67: init_word = {1'b1, 8'h00};
        68: init_word = {1'b1, LCD_Y_END[15:8]};
        69: init_word = {1'b1, LCD_Y_END[7:0]};
        70: init_word = {1'b0, 8'h21};
        71: init_word = {1'b0, 8'h29};
        default: init_word = {1'b0, 8'h00};
      endcase
    end
  endfunction

  function automatic logic [31:0] delay_after_word(input logic [6:0] index);
    begin
      unique case (index)
        1:  delay_after_word = SLEEP_OUT_CYCLES;
        69: delay_after_word = WINDOW_WAIT_CYCLES;
        71: delay_after_word = FINAL_WAIT_CYCLES;
        default: delay_after_word = 0;
      endcase
    end
  endfunction

  assign current_word  = init_word(word_index_q);
  assign current_delay = delay_after_word(word_index_q);
  assign tx_start      = state_q == SEND_WORD && tx_ready;
  assign initialized_o = state_q == COMPLETE;
  assign busy_o        = state_q != COMPLETE;

  display_spi_byte_tx #(
      .SPI_CLK_DIV(SPI_CLK_DIV)
  ) i_display_spi_byte_tx (
      .clk_i,
      .rst_ni,
      .start_i  (tx_start),
      .data_i   (current_word[7:0]),
      .dc_i     (current_word[8]),
      .keep_cs_i((current_delay == 0) && (word_index_q != INIT_WORDS - 1)),
      .ready_o  (tx_ready),
      .busy_o   (),
      .done_o   (tx_done),
      .spi_cs_no,
      .spi_sclk_o,
      .spi_mosi_o
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q        <= ENABLE ? RESET_LOW : COMPLETE;
      word_index_q   <= '0;
      delay_count_q  <= '0;
      delay_target_q <= '0;
      lcd_reset_no   <= ENABLE ? 1'b0 : 1'b1;
    end else begin
      unique case (state_q)
        RESET_LOW: begin
          lcd_reset_no <= 1'b0;
          if (delay_count_q == RESET_LOW_CYCLES - 1) begin
            delay_count_q <= '0;
            lcd_reset_no  <= 1'b1;
            state_q       <= RESET_HIGH;
          end else begin
            delay_count_q <= delay_count_q + 1'b1;
          end
        end

        RESET_HIGH: begin
          if (delay_count_q == RESET_HIGH_CYCLES - 1) begin
            delay_count_q <= '0;
            state_q       <= SEND_WORD;
          end else begin
            delay_count_q <= delay_count_q + 1'b1;
          end
        end

        SEND_WORD: begin
          if (tx_ready) state_q <= WAIT_WORD;
        end

        WAIT_WORD: begin
          if (tx_done) begin
            if (current_delay != 0) begin
              delay_count_q  <= '0;
              delay_target_q <= current_delay;
              state_q        <= WAIT_DELAY;
            end else if (word_index_q == INIT_WORDS - 1) begin
              state_q <= COMPLETE;
            end else begin
              word_index_q <= word_index_q + 1'b1;
              state_q      <= SEND_WORD;
            end
          end
        end

        WAIT_DELAY: begin
          if (delay_count_q == delay_target_q - 1) begin
            delay_count_q <= '0;
            if (word_index_q == INIT_WORDS - 1) begin
              state_q <= COMPLETE;
            end else begin
              word_index_q <= word_index_q + 1'b1;
              state_q      <= SEND_WORD;
            end
          end else begin
            delay_count_q <= delay_count_q + 1'b1;
          end
        end

        default: begin
          lcd_reset_no <= 1'b1;
          state_q      <= COMPLETE;
        end
      endcase
    end
  end

endmodule
