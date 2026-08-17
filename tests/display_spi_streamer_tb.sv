module display_spi_streamer_tb;

  localparam logic [31:0] BASE_ADDR = 32'h1A40_0000;
  localparam logic [31:0] CONTROL_ADDR = BASE_ADDR + 32'h0000_0000;
  localparam logic [31:0] STATUS_ADDR = BASE_ADDR + 32'h0000_0004;
  localparam logic [31:0] FRAME_COUNTER_ADDR = BASE_ADDR + 32'h0000_0008;
  localparam logic [31:0] PALETTE_ADDR = BASE_ADDR + 32'h0000_1000;
  localparam logic [31:0] FRAMEBUFFER_ADDR = BASE_ADDR + 32'h0001_0000;
  localparam int unsigned FRAME_WIDTH = 320;
  localparam int unsigned FRAME_HEIGHT = 200;
  localparam int unsigned FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;
  localparam int unsigned PIXEL_ADDR_WIDTH = $clog2(FRAME_PIXELS);

  logic clk;
  logic rst_n;

  logic        tcdm_req;
  logic [31:0] tcdm_add;
  logic        tcdm_wen;
  logic [31:0] tcdm_wdata;
  logic [3:0]  tcdm_be;
  logic        tcdm_gnt;
  logic        tcdm_r_opc;
  logic [31:0] tcdm_r_rdata;
  logic        tcdm_r_valid;

  logic pixel_req;
  logic [PIXEL_ADDR_WIDTH-1:0] pixel_addr;
  logic [7:0] pixel;
  logic palette_req;
  logic [7:0] palette_index;
  logic [15:0] palette_color;

  logic display_enable;
  logic frame_start;
  logic display_busy;
  logic display_done;
  logic spi_cs_n;
  logic spi_sclk;
  logic spi_mosi;

  logic [15:0] received_shift;
  logic [31:0] packed_pixels;
  logic [31:0] read_data;
  logic read_error;
  integer pixel_number;
  integer received_bits;
  integer received_pixels;
  integer timeout;

  display_tcdm_slave_core #(
      .BASE_ADDR   (BASE_ADDR),
      .FRAME_WIDTH (FRAME_WIDTH),
      .FRAME_HEIGHT(FRAME_HEIGHT)
  ) display_memory_i (
      .clk_i                  (clk),
      .rst_ni                 (rst_n),
      .tcdm_req_i             (tcdm_req),
      .tcdm_add_i             (tcdm_add),
      .tcdm_wen_i             (tcdm_wen),
      .tcdm_wdata_i           (tcdm_wdata),
      .tcdm_be_i              (tcdm_be),
      .tcdm_gnt_o             (tcdm_gnt),
      .tcdm_r_opc_o           (tcdm_r_opc),
      .tcdm_r_rdata_o         (tcdm_r_rdata),
      .tcdm_r_valid_o         (tcdm_r_valid),
      .display_pixel_req_i    (pixel_req),
      .display_pixel_addr_i   (pixel_addr),
      .display_pixel_o        (pixel),
      .display_palette_req_i  (palette_req),
      .display_palette_index_i(palette_index),
      .display_color_o        (palette_color),
      .display_enable_o       (display_enable),
      .frame_start_o          (frame_start),
      .display_busy_i         (display_busy),
      .display_done_i         (display_done)
  );

  display_spi_streamer #(
      .FRAME_PIXELS    (FRAME_PIXELS),
      .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH),
      .SPI_CLK_DIV     (1)
  ) spi_streamer_i (
      .clk_i             (clk),
      .rst_ni           (rst_n),
      .frame_start_i    (frame_start),
      .display_enable_i (display_enable),
      .busy_o           (display_busy),
      .done_o           (display_done),
      .pixel_req_o      (pixel_req),
      .pixel_addr_o     (pixel_addr),
      .pixel_i          (pixel),
      .palette_req_o    (palette_req),
      .palette_index_o  (palette_index),
      .palette_color_i  (palette_color),
      .spi_cs_no        (spi_cs_n),
      .spi_sclk_o       (spi_sclk),
      .spi_mosi_o       (spi_mosi)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [7:0] pattern_index(input integer pixel_number);
    integer pattern_x;
    integer pattern_y;
    begin
      pattern_x = pixel_number % FRAME_WIDTH;
      pattern_y = pixel_number / FRAME_WIDTH;

      if (pattern_y < 120) begin
        pattern_index = pattern_x / 40;
      end else begin
        pattern_index = ((pattern_x / 20) + (pattern_y / 20)) % 8;
      end
    end
  endfunction

  function automatic logic [15:0] expected_color(input integer pixel_number);
    begin
      unique case (pattern_index(pixel_number))
        8'd0: expected_color = 16'h0000;
        8'd1: expected_color = 16'hF800;
        8'd2: expected_color = 16'h07E0;
        8'd3: expected_color = 16'h001F;
        8'd4: expected_color = 16'hFFFF;
        8'd5: expected_color = 16'hFFE0;
        8'd6: expected_color = 16'h07FF;
        default: expected_color = 16'hF81F;
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
      data  = tcdm_r_rdata;
      error = tcdm_r_opc;
      if (!tcdm_gnt || !tcdm_r_valid) $fatal(1, "TCDM read did not complete");

      @(negedge clk);
      tcdm_idle();
    end
  endtask

  always @(posedge spi_sclk) begin
    if (!spi_cs_n) begin
      received_shift = {received_shift[14:0], spi_mosi};
      if (received_bits == 15) begin
        if (received_shift !== expected_color(received_pixels)) begin
          $fatal(1, "SPI pixel %0d: expected %04x, received %04x",
                 received_pixels, expected_color(received_pixels),
                 received_shift);
        end
        received_pixels = received_pixels + 1;
        received_bits   = 0;
        received_shift  = '0;
      end else begin
        received_bits = received_bits + 1;
      end
    end
  end

  initial begin
    rst_n           = 1'b0;
    received_shift  = '0;
    received_bits   = 0;
    received_pixels = 0;
    tcdm_idle();

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    tcdm_write(PALETTE_ADDR + 32'h0, 32'hF800_0000);
    tcdm_write(PALETTE_ADDR + 32'h4, 32'h001F_07E0);
    tcdm_write(PALETTE_ADDR + 32'h8, 32'hFFE0_FFFF);
    tcdm_write(PALETTE_ADDR + 32'hC, 32'hF81F_07FF);

    for (pixel_number = 0; pixel_number < FRAME_PIXELS; pixel_number += 4) begin
      packed_pixels[7:0]   = pattern_index(pixel_number + 0);
      packed_pixels[15:8]  = pattern_index(pixel_number + 1);
      packed_pixels[23:16] = pattern_index(pixel_number + 2);
      packed_pixels[31:24] = pattern_index(pixel_number + 3);
      tcdm_write(FRAMEBUFFER_ADDR + pixel_number, packed_pixels);
    end

    // Enable the controller and pulse the start bit through the real register path.
    tcdm_write(CONTROL_ADDR, 32'h0000_0001);
    tcdm_write(CONTROL_ADDR, 32'h0000_0003);

    timeout = 0;
    while (!display_done && timeout < 3_000_000) begin
      @(posedge clk);
      timeout = timeout + 1;
    end
    if (!display_done) $fatal(1, "Timed out waiting for the SPI frame");
    if (received_pixels != FRAME_PIXELS) begin
      $fatal(1, "Expected %0d SPI pixels, received %0d", FRAME_PIXELS, received_pixels);
    end

    // Allow the slave to capture the controller's done pulse.
    repeat (2) @(posedge clk);
    tcdm_read(STATUS_ADDR, read_data, read_error);
    if (read_error || read_data[1:0] !== 2'b10) begin
      $fatal(1, "Unexpected final display status %08x", read_data);
    end
    tcdm_read(FRAME_COUNTER_ADDR, read_data, read_error);
    if (read_error || read_data !== 32'd1) begin
      $fatal(1, "Expected frame counter 1, received %08x", read_data);
    end

    $display("PASS: framebuffer and palette streamed %0d RGB565 pixels over SPI",
             FRAME_PIXELS);
    $finish;
  end

endmodule
