module display_tcdm_slave_tb;

  localparam logic [31:0] BASE_ADDR = 32'h1A40_0000;
  localparam int unsigned FRAME_WIDTH = 320;
  localparam int unsigned FRAME_HEIGHT = 200;
  localparam int unsigned FRAME_BYTES = FRAME_WIDTH * FRAME_HEIGHT;
  localparam int unsigned PIXEL_ADDR_WIDTH = $clog2(FRAME_BYTES);

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

  logic display_pixel_req;
  logic [PIXEL_ADDR_WIDTH-1:0] display_pixel_addr;
  logic [7:0] display_pixel;
  logic display_palette_req;
  logic [7:0] display_palette_index;
  logic [15:0] display_color;
  logic display_enable;
  logic frame_start;
  logic display_busy;
  logic display_done;

  display_tcdm_slave_core #(
      .BASE_ADDR   (BASE_ADDR),
      .FRAME_WIDTH (FRAME_WIDTH),
      .FRAME_HEIGHT(FRAME_HEIGHT)
  ) dut (
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
      .display_pixel_req_i    (display_pixel_req),
      .display_pixel_addr_i   (display_pixel_addr),
      .display_pixel_o        (display_pixel),
      .display_palette_req_i  (display_palette_req),
      .display_palette_index_i(display_palette_index),
      .display_color_o        (display_color),
      .display_enable_o       (display_enable),
      .frame_start_o          (frame_start),
      .display_busy_i         (display_busy),
      .display_done_i         (display_done)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic tcdm_idle;
    begin
      tcdm_req   = 1'b0;
      tcdm_add   = '0;
      tcdm_wen   = 1'b1;
      tcdm_wdata = '0;
      tcdm_be    = '0;
    end
  endtask

  task automatic tcdm_write(
      input logic [31:0] address,
      input logic [31:0] data,
      input logic [3:0]  byte_enable
  );
    begin
      @(negedge clk);
      tcdm_req   = 1'b1;
      tcdm_add   = address;
      tcdm_wen   = 1'b0;
      tcdm_wdata = data;
      tcdm_be    = byte_enable;

      @(posedge clk);
      #1;
      if (tcdm_gnt !== 1'b1) $fatal(1, "TCDM write was not granted");
      if (tcdm_r_valid !== 1'b1) $fatal(1, "TCDM write response was not valid");
      if (tcdm_r_opc !== 1'b0) $fatal(1, "TCDM write returned an error");

      @(negedge clk);
      tcdm_idle();
    end
  endtask

  task automatic tcdm_read(
      input  logic [31:0] address,
      output logic [31:0] data,
      output logic        error
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
      if (tcdm_gnt !== 1'b1) $fatal(1, "TCDM read was not granted");
      if (tcdm_r_valid !== 1'b1) $fatal(1, "TCDM read response was not valid");
      data  = tcdm_r_rdata;
      error = tcdm_r_opc;

      @(negedge clk);
      tcdm_idle();
    end
  endtask

  task automatic display_read_pixel(
      input logic [PIXEL_ADDR_WIDTH-1:0] address,
      input logic [7:0] expected
  );
    begin
      @(negedge clk);
      display_pixel_req  = 1'b1;
      display_pixel_addr = address;
      @(posedge clk);
      #1;
      if (display_pixel !== expected) begin
        $fatal(1, "Pixel %0d mismatch: expected %02h, got %02h",
               address, expected, display_pixel);
      end
      @(negedge clk);
      display_pixel_req = 1'b0;
    end
  endtask

  task automatic display_read_palette(
      input logic [7:0]  index,
      input logic [15:0] expected
  );
    begin
      @(negedge clk);
      display_palette_req   = 1'b1;
      display_palette_index = index;
      @(posedge clk);
      #1;
      if (display_color !== expected) begin
        $fatal(1, "Palette %0d mismatch: expected %04h, got %04h",
               index, expected, display_color);
      end
      @(negedge clk);
      display_palette_req = 1'b0;
    end
  endtask

  initial begin : test_sequence
    logic [31:0] read_data;
    logic read_error;

    tcdm_idle();
    display_pixel_req     = 1'b0;
    display_pixel_addr    = '0;
    display_palette_req   = 1'b0;
    display_palette_index = '0;
    display_busy          = 1'b0;
    display_done          = 1'b0;
    rst_n                 = 1'b0;

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    tcdm_read(BASE_ADDR + 32'h0000_000C, read_data, read_error);
    if (read_error || read_data !== 32'h0000_0000) begin
      $fatal(1, "Scratch register did not reset to zero");
    end

    tcdm_write(BASE_ADDR + 32'h0000_000C, 32'h1122_3344, 4'hF);
    tcdm_read(BASE_ADDR + 32'h0000_000C, read_data, read_error);
    if (read_error || read_data !== 32'h1122_3344) begin
      $fatal(1, "Scratch full-word readback failed: %08h", read_data);
    end

    tcdm_write(BASE_ADDR + 32'h0000_000C, 32'hAA00_CC00, 4'b1010);
    tcdm_read(BASE_ADDR + 32'h0000_000C, read_data, read_error);
    if (read_error || read_data !== 32'hAA22_CC44) begin
      $fatal(1, "Scratch byte-enable readback failed: %08h", read_data);
    end

    tcdm_write(BASE_ADDR + 32'h0000_0000, 32'h0000_0003, 4'b0001);
    if (display_enable !== 1'b1) $fatal(1, "Display enable did not set");
    if (frame_start !== 1'b1) $fatal(1, "Frame start did not pulse");

    display_busy = 1'b1;
    tcdm_read(BASE_ADDR + 32'h0000_0004, read_data, read_error);
    if (read_error || read_data[0] !== 1'b1) $fatal(1, "Busy status did not read high");
    display_busy = 1'b0;

    @(negedge clk);
    display_done = 1'b1;
    @(posedge clk);
    @(negedge clk);
    display_done = 1'b0;

    tcdm_read(BASE_ADDR + 32'h0000_0004, read_data, read_error);
    if (read_error || read_data[1] !== 1'b1) $fatal(1, "Done status did not latch");
    tcdm_read(BASE_ADDR + 32'h0000_0008, read_data, read_error);
    if (read_error || read_data !== 32'h0000_0001) $fatal(1, "Frame counter did not increment");

    tcdm_write(BASE_ADDR + 32'h0001_0000, 32'h4433_2211, 4'hF);
    tcdm_read(BASE_ADDR + 32'h0001_0000, read_data, read_error);
    if (read_error || read_data !== 32'h4433_2211) begin
      $fatal(1, "Framebuffer readback failed: %08h", read_data);
    end
    display_read_pixel(0, 8'h11);
    display_read_pixel(1, 8'h22);
    display_read_pixel(2, 8'h33);
    display_read_pixel(3, 8'h44);

    @(negedge clk);
    tcdm_req          = 1'b1;
    tcdm_add          = BASE_ADDR + 32'h0001_0000;
    tcdm_wen          = 1'b0;
    tcdm_wdata        = 32'h8877_6655;
    tcdm_be           = 4'hF;
    display_pixel_req = 1'b1;
    display_pixel_addr = '0;
    @(posedge clk);
    #1;
    if (display_pixel !== 8'h11) begin
      $fatal(1, "Framebuffer collision was not read-before-write: %02h", display_pixel);
    end
    @(negedge clk);
    tcdm_idle();
    display_pixel_req = 1'b0;
    tcdm_read(BASE_ADDR + 32'h0001_0000, read_data, read_error);
    if (read_error || read_data !== 32'h8877_6655) begin
      $fatal(1, "Framebuffer collision write did not complete: %08h", read_data);
    end

    tcdm_write(BASE_ADDR + 32'h0001_0000, 32'h00AA_00BB, 4'b0101);
    tcdm_read(BASE_ADDR + 32'h0001_0000, read_data, read_error);
    if (read_error || read_data !== 32'h88AA_66BB) begin
      $fatal(1, "Framebuffer byte-enable readback failed: %08h", read_data);
    end

    tcdm_write(BASE_ADDR + 32'h0000_1000, 32'hABCD_1234, 4'hF);
    tcdm_read(BASE_ADDR + 32'h0000_1000, read_data, read_error);
    if (read_error || read_data !== 32'hABCD_1234) begin
      $fatal(1, "Palette readback failed: %08h", read_data);
    end
    display_read_palette(0, 16'h1234);
    display_read_palette(1, 16'hABCD);

    tcdm_read(BASE_ADDR + 32'h0000_2000, read_data, read_error);
    if (!read_error || read_data !== 32'hBADACCE5) begin
      $fatal(1, "Invalid address did not return the expected error response");
    end

    $display("PASS: display_tcdm_slave register, framebuffer and palette tests");
    $finish;
  end

endmodule
