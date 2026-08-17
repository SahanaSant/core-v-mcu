module display_st7789_init_tb;

  localparam int unsigned INIT_WORDS = 72;

  logic clk;
  logic rst_n;
  logic initialized;
  logic busy;
  logic lcd_reset_n;
  logic spi_cs_n;
  logic spi_sclk;
  logic spi_mosi;

  logic [8:0] expected_words [0:INIT_WORDS-1];
  logic [8:0] received_word;
  integer received_bits;
  integer received_words;
  integer timeout;

  display_st7789_init #(
      .ENABLE      (1'b1),
      .CLK_FREQ_HZ (1000),
      .SPI_CLK_DIV (1),
      .LCD_WIDTH   (320),
      .LCD_HEIGHT  (240),
      .MADCTL_VALUE(8'h20)
  ) dut (
      .clk_i        (clk),
      .rst_ni       (rst_n),
      .initialized_o(initialized),
      .busy_o       (busy),
      .lcd_reset_no (lcd_reset_n),
      .spi_cs_no    (spi_cs_n),
      .spi_sclk_o   (spi_sclk),
      .spi_mosi_o   (spi_mosi)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  always @(posedge spi_sclk) begin
    if (!spi_cs_n) begin
      received_word = {received_word[7:0], spi_mosi};
      if (received_bits == 8) begin
        if (received_words >= INIT_WORDS) begin
          $fatal(1, "Received too many ST7789 initialization words");
        end
        if (received_word !== expected_words[received_words]) begin
          $fatal(1, "ST7789 init word %0d: expected %03x, received %03x",
                 received_words, expected_words[received_words], received_word);
        end
        received_words = received_words + 1;
        received_bits  = 0;
        received_word  = '0;
      end else begin
        received_bits = received_bits + 1;
      end
    end
  end

  initial begin
    expected_words[0]  = {1'b0, 8'h28};
    expected_words[1]  = {1'b0, 8'h11};
    expected_words[2]  = {1'b0, 8'h36};
    expected_words[3]  = {1'b1, 8'h20};
    expected_words[4]  = {1'b0, 8'h3A};
    expected_words[5]  = {1'b1, 8'h55};
    expected_words[6]  = {1'b0, 8'hB2};
    expected_words[7]  = {1'b1, 8'h0C};
    expected_words[8]  = {1'b1, 8'h0C};
    expected_words[9]  = {1'b1, 8'h00};
    expected_words[10] = {1'b1, 8'h33};
    expected_words[11] = {1'b1, 8'h33};
    expected_words[12] = {1'b0, 8'hB7};
    expected_words[13] = {1'b1, 8'h35};
    expected_words[14] = {1'b0, 8'hBB};
    expected_words[15] = {1'b1, 8'h2B};
    expected_words[16] = {1'b0, 8'hC0};
    expected_words[17] = {1'b1, 8'h2C};
    expected_words[18] = {1'b0, 8'hC2};
    expected_words[19] = {1'b1, 8'h01};
    expected_words[20] = {1'b1, 8'hFF};
    expected_words[21] = {1'b0, 8'hC3};
    expected_words[22] = {1'b1, 8'h11};
    expected_words[23] = {1'b0, 8'hC4};
    expected_words[24] = {1'b1, 8'h20};
    expected_words[25] = {1'b0, 8'hC6};
    expected_words[26] = {1'b1, 8'h0F};
    expected_words[27] = {1'b0, 8'hD0};
    expected_words[28] = {1'b1, 8'hA4};
    expected_words[29] = {1'b1, 8'hA1};
    expected_words[30] = {1'b0, 8'hE0};
    expected_words[31] = {1'b1, 8'hD0};
    expected_words[32] = {1'b1, 8'h00};
    expected_words[33] = {1'b1, 8'h05};
    expected_words[34] = {1'b1, 8'h0E};
    expected_words[35] = {1'b1, 8'h15};
    expected_words[36] = {1'b1, 8'h0D};
    expected_words[37] = {1'b1, 8'h37};
    expected_words[38] = {1'b1, 8'h43};
    expected_words[39] = {1'b1, 8'h47};
    expected_words[40] = {1'b1, 8'h09};
    expected_words[41] = {1'b1, 8'h15};
    expected_words[42] = {1'b1, 8'h12};
    expected_words[43] = {1'b1, 8'h16};
    expected_words[44] = {1'b1, 8'h19};
    expected_words[45] = {1'b0, 8'hE1};
    expected_words[46] = {1'b1, 8'hD0};
    expected_words[47] = {1'b1, 8'h00};
    expected_words[48] = {1'b1, 8'h05};
    expected_words[49] = {1'b1, 8'h0D};
    expected_words[50] = {1'b1, 8'h0C};
    expected_words[51] = {1'b1, 8'h06};
    expected_words[52] = {1'b1, 8'h2D};
    expected_words[53] = {1'b1, 8'h44};
    expected_words[54] = {1'b1, 8'h40};
    expected_words[55] = {1'b1, 8'h0E};
    expected_words[56] = {1'b1, 8'h1C};
    expected_words[57] = {1'b1, 8'h18};
    expected_words[58] = {1'b1, 8'h16};
    expected_words[59] = {1'b1, 8'h19};
    expected_words[60] = {1'b0, 8'h2A};
    expected_words[61] = {1'b1, 8'h00};
    expected_words[62] = {1'b1, 8'h00};
    expected_words[63] = {1'b1, 8'h01};
    expected_words[64] = {1'b1, 8'h3F};
    expected_words[65] = {1'b0, 8'h2B};
    expected_words[66] = {1'b1, 8'h00};
    expected_words[67] = {1'b1, 8'h00};
    expected_words[68] = {1'b1, 8'h00};
    expected_words[69] = {1'b1, 8'hEF};
    expected_words[70] = {1'b0, 8'h21};
    expected_words[71] = {1'b0, 8'h29};

    rst_n          = 1'b0;
    received_word  = '0;
    received_bits  = 0;
    received_words = 0;

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    if (lcd_reset_n !== 1'b0 || initialized || !busy) begin
      $fatal(1, "ST7789 initializer did not enter hardware reset");
    end

    timeout = 0;
    while (!initialized && timeout < 5000) begin
      @(posedge clk);
      timeout = timeout + 1;
    end

    if (!initialized) $fatal(1, "Timed out waiting for ST7789 initialization");
    if (received_words != INIT_WORDS) begin
      $fatal(1, "Expected %0d ST7789 init words, received %0d",
             INIT_WORDS, received_words);
    end
    if (lcd_reset_n !== 1'b1 || busy || !spi_cs_n || spi_sclk) begin
      $fatal(1, "ST7789 initializer did not finish in the idle state");
    end

    $display("PASS: ST7789VI reset and %0d-word 3-wire initialization sequence",
             INIT_WORDS);
    $finish;
  end

endmodule
