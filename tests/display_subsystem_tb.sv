module display_subsystem_tb;

  localparam logic [31:0] BASE_ADDR         = 32'h1A40_0000;
  localparam logic [31:0] CONTROL_ADDR      = BASE_ADDR + 32'h0000_0000;
  localparam logic [31:0] STATUS_ADDR       = BASE_ADDR + 32'h0000_0004;
  localparam logic [31:0] FRAME_COUNTER_ADDR = BASE_ADDR + 32'h0000_0008;
  localparam logic [31:0] PALETTE_ADDR      = BASE_ADDR + 32'h0000_1000;
  localparam logic [31:0] FRAMEBUFFER_ADDR  = BASE_ADDR + 32'h0001_0000;
  localparam int unsigned FRAME_WIDTH       = 4;
  localparam int unsigned FRAME_HEIGHT      = 2;
  localparam int unsigned FRAME_PIXELS      = FRAME_WIDTH * FRAME_HEIGHT;

  logic clk;
  logic rst_n;
  logic spi_cs_n;
  logic spi_sclk;
  logic spi_mosi;

  logic        tcdm_req;
  logic [31:0] tcdm_add;
  logic        tcdm_wen;
  logic [31:0] tcdm_wdata;
  logic [3:0]  tcdm_be;
  logic        tcdm_gnt;
  logic        tcdm_r_opc;
  logic [31:0] tcdm_r_rdata;
  logic        tcdm_r_valid;

  logic [15:0] received_shift;
  logic [7:0]  received_byte;
  logic        received_dc;
  logic [31:0] read_data;
  logic        read_error;
  integer      received_bits;
  integer      received_bytes;
  integer      received_words;
  integer      received_pixels;
  integer      timeout;

  display_subsystem_core #(
      .BASE_ADDR   (BASE_ADDR),
      .FRAME_WIDTH (FRAME_WIDTH),
      .FRAME_HEIGHT(FRAME_HEIGHT),
      .SPI_CLK_DIV (1),
      .ST7789_INIT_ENABLE(1'b0)
  ) dut (
      .clk_i      (clk),
      .rst_ni     (rst_n),
      .tcdm_req_i    (tcdm_req),
      .tcdm_add_i    (tcdm_add),
      .tcdm_wen_i    (tcdm_wen),
      .tcdm_wdata_i  (tcdm_wdata),
      .tcdm_be_i     (tcdm_be),
      .tcdm_gnt_o    (tcdm_gnt),
      .tcdm_r_opc_o  (tcdm_r_opc),
      .tcdm_r_rdata_o(tcdm_r_rdata),
      .tcdm_r_valid_o(tcdm_r_valid),
      .spi_cs_no  (spi_cs_n),
      .spi_sclk_o (spi_sclk),
      .spi_mosi_o (spi_mosi)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [15:0] expected_color(input integer pixel_number);
    begin
      unique case (pixel_number)
        0, 7: expected_color = 16'hF800;
        1, 6: expected_color = 16'h07E0;
        2, 5: expected_color = 16'h001F;
        default: expected_color = 16'hFFFF;
      endcase
    end
  endfunction

  task automatic tcdm_idle;
    begin
      tcdm_req   = 1'b0;
      tcdm_add   = '0;
      tcdm_wen   = 1'b1;
      tcdm_wdata = '0;
      tcdm_be    = '0;
    end
  endtask

  task automatic tcdm_write(input logic [31:0] address, input logic [31:0] data);
    begin
      @(negedge clk);
      tcdm_req   = 1'b1;
      tcdm_add   = address;
      tcdm_wen   = 1'b0;
      tcdm_wdata = data;
      tcdm_be    = 4'hF;

      @(posedge clk);
      #1;
      if (!tcdm_gnt || !tcdm_r_valid || tcdm_r_opc) begin
        $fatal(1, "TCDM write failed at address %08x", address);
      end

      @(negedge clk);
      tcdm_idle();
    end
  endtask

  task automatic tcdm_read(
      input logic [31:0] address,
      output logic [31:0] data,
      output logic error
  );
    begin
      @(negedge clk);
      tcdm_req   = 1'b1;
      tcdm_add   = address;
      tcdm_wen   = 1'b1;
      tcdm_wdata = '0;
      tcdm_be    = 4'hF;

      @(posedge clk);
      #1;
      if (!tcdm_gnt || !tcdm_r_valid) begin
        $fatal(1, "TCDM read did not complete at address %08x", address);
      end
      data  = tcdm_r_rdata;
      error = tcdm_r_opc;

      @(negedge clk);
      tcdm_idle();
    end
  endtask

  always @(posedge spi_sclk) begin
    if (!spi_cs_n) begin
      if (received_bits == 0) begin
        received_dc   = spi_mosi;
        received_byte = '0;
        received_bits = 1;
      end else begin
        received_byte = {received_byte[6:0], spi_mosi};
        if (received_bits == 8) begin
          if (received_words == 0) begin
            if (received_dc !== 1'b0 || received_byte !== 8'h2C) begin
              $fatal(1, "Expected 3-wire command 02c before pixel data");
            end
          end else begin
            if (received_dc !== 1'b1) begin
              $fatal(1, "Pixel byte was not prefixed with the 3-wire data bit");
            end
            if (!received_bytes[0]) begin
              received_shift[15:8] = received_byte;
            end else begin
              received_shift[7:0] = received_byte;
            end
            if (received_bytes[0]) begin
            if (received_shift !== expected_color(received_pixels)) begin
              $fatal(1, "SPI pixel %0d: expected %04x, received %04x",
                     received_pixels, expected_color(received_pixels), received_shift);
            end
            received_pixels = received_pixels + 1;
            received_shift  = '0;
            end
            received_bytes = received_bytes + 1;
          end
          received_words = received_words + 1;
          received_bits  = 0;
        end else begin
          received_bits = received_bits + 1;
        end
      end
    end
  end

  initial begin
    rst_n           = 1'b0;
    received_shift  = '0;
    received_byte   = '0;
    received_dc     = 1'b0;
    received_bits   = 0;
    received_bytes  = 0;
    received_words  = 0;
    received_pixels = 0;
    tcdm_idle();

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    // Palette indexes 0..3: red, green, blue and white.
    tcdm_write(PALETTE_ADDR + 32'h0, 32'h07E0_F800);
    tcdm_write(PALETTE_ADDR + 32'h4, 32'hFFFF_001F);

    // Eight indexed pixels: 0,1,2,3,3,2,1,0.
    tcdm_write(FRAMEBUFFER_ADDR + 32'h0, 32'h0302_0100);
    tcdm_write(FRAMEBUFFER_ADDR + 32'h4, 32'h0001_0203);

    // Set enable and pulse start through the real memory-mapped register.
    tcdm_write(CONTROL_ADDR, 32'h0000_0003);

    timeout = 0;
    while ((received_pixels < FRAME_PIXELS || !spi_cs_n) && timeout < 5000) begin
      @(posedge clk);
      timeout = timeout + 1;
    end
    if (timeout == 5000) $fatal(1, "Timed out waiting for the SPI frame");
    if (received_pixels != FRAME_PIXELS) begin
      $fatal(1, "Expected %0d SPI pixels, received %0d", FRAME_PIXELS, received_pixels);
    end

    repeat (2) @(posedge clk);
    tcdm_read(STATUS_ADDR, read_data, read_error);
    if (read_error || read_data[1:0] !== 2'b10) begin
      $fatal(1, "Unexpected final display status %08x", read_data);
    end
    tcdm_read(FRAME_COUNTER_ADDR, read_data, read_error);
    if (read_error || read_data !== 32'd1) begin
      $fatal(1, "Expected frame counter 1, received %08x", read_data);
    end

    $display("PASS: integrated TCDM display subsystem streamed %0d RGB565 pixels",
             FRAME_PIXELS);
    $finish;
  end

endmodule
