module display_framebuffer_image_tb;

  localparam logic [31:0] BASE_ADDR = 32'h1A40_0000;
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

  logic display_pixel_req;
  logic [PIXEL_ADDR_WIDTH-1:0] display_pixel_addr;
  logic [7:0] display_pixel;
  logic display_palette_req;
  logic [7:0] display_palette_index;
  logic [15:0] display_color;

  integer image_file;
  integer pixel_number;
  integer red;
  integer green;
  integer blue;
  logic [31:0] packed_pixels;
  logic [15:0] actual_color;
  logic [15:0] expected_color;

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
      .display_enable_o       (),
      .frame_start_o          (),
      .display_busy_i         (1'b0),
      .display_done_i         (1'b0)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [7:0] pattern_index(input integer pixel);
    integer pattern_x;
    integer pattern_y;
    begin
      pattern_x = pixel % FRAME_WIDTH;
      pattern_y = pixel / FRAME_WIDTH;

      if (pattern_y < 120) begin
        pattern_index = pattern_x / 40;
      end else begin
        pattern_index = ((pattern_x / 20) + (pattern_y / 20)) % 8;
      end
    end
  endfunction

  function automatic logic [15:0] palette_color(input logic [7:0] index);
    begin
      unique case (index)
        8'd0: palette_color = 16'h0000;
        8'd1: palette_color = 16'hF800;
        8'd2: palette_color = 16'h07E0;
        8'd3: palette_color = 16'h001F;
        8'd4: palette_color = 16'hFFFF;
        8'd5: palette_color = 16'hFFE0;
        8'd6: palette_color = 16'h07FF;
        default: palette_color = 16'hF81F;
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

  task automatic read_display_color(
      input integer pixel,
      output logic [15:0] color
  );
    begin
      @(negedge clk);
      display_pixel_req  = 1'b1;
      display_pixel_addr = pixel[PIXEL_ADDR_WIDTH-1:0];

      @(posedge clk);
      #1;
      @(negedge clk);
      display_pixel_req     = 1'b0;
      display_palette_req   = 1'b1;
      display_palette_index = display_pixel;

      @(posedge clk);
      #1;
      color = display_color;
      @(negedge clk);
      display_palette_req = 1'b0;
    end
  endtask

  initial begin
    rst_n                 = 1'b0;
    display_pixel_req     = 1'b0;
    display_pixel_addr    = '0;
    display_palette_req   = 1'b0;
    display_palette_index = '0;
    tcdm_idle();

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    // Eight RGB565 colors, packed two palette entries per TCDM word.
    tcdm_write(PALETTE_ADDR + 32'h0, 32'hF800_0000);
    tcdm_write(PALETTE_ADDR + 32'h4, 32'h001F_07E0);
    tcdm_write(PALETTE_ADDR + 32'h8, 32'hFFE0_FFFF);
    tcdm_write(PALETTE_ADDR + 32'hC, 32'hF81F_07FF);

    // Fill all 64,000 pixels through the same 32-bit TCDM path used by software.
    for (pixel_number = 0; pixel_number < FRAME_PIXELS; pixel_number += 4) begin
      packed_pixels[7:0]   = pattern_index(pixel_number + 0);
      packed_pixels[15:8]  = pattern_index(pixel_number + 1);
      packed_pixels[23:16] = pattern_index(pixel_number + 2);
      packed_pixels[31:24] = pattern_index(pixel_number + 3);
      tcdm_write(FRAMEBUFFER_ADDR + pixel_number, packed_pixels);
    end

    image_file = $fopen("display_framebuffer_test.ppm", "w");
    if (image_file == 0) $fatal(1, "Could not create display_framebuffer_test.ppm");
    $fwrite(image_file, "P3\n%0d %0d\n255\n", FRAME_WIDTH, FRAME_HEIGHT);

    for (pixel_number = 0; pixel_number < FRAME_PIXELS; pixel_number += 1) begin
      read_display_color(pixel_number, actual_color);
      expected_color = palette_color(pattern_index(pixel_number));
      if (actual_color !== expected_color) begin
        $fatal(1, "Pixel %0d: expected %04x, received %04x",
               pixel_number, expected_color, actual_color);
      end

      red   = {actual_color[15:11], actual_color[15:13]};
      green = {actual_color[10:5], actual_color[10:9]};
      blue  = {actual_color[4:0], actual_color[4:2]};
      $fwrite(image_file, "%0d %0d %0d\n", red, green, blue);
    end

    $fclose(image_file);
    $display("PASS: generated and verified 320x200 display_framebuffer_test.ppm");
    $finish;
  end

endmodule
