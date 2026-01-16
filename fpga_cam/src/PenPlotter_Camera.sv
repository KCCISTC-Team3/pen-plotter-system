`timescale 1ns / 1ps

module PenPlotter_Camera (
    input  logic       clk,
    input  logic       reset,
    // OV7670 Camera
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    // I2C
    output tri         SCL,
    inout  tri         SDA,
    // Button
    input  logic       cap_btn,
    // UART
    input  logic       rx,
    output logic       tx,
    output logic       led_capture,
    output logic       led_sending,
    // HDMI TMDS out
    output wire        TMDS_Clk_p,
    output wire        TMDS_Clk_n,
    output wire  [2:0] TMDS_Data_p,
    output wire  [2:0] TMDS_Data_n
);
    // ===== Parameters =====
    localparam DATA_WIDTH = 8;
    localparam RGB_WIDTH = DATA_WIDTH * 3;
    localparam IMG_WIDTH = 176;
    localparam IMG_HEIGHT = 240;
    localparam CAM_WIDTH = 320;
    localparam CAM_HEIGHT = 240;
    localparam ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT);

    // UART Parameters
    localparam CLK_FREQ = 125_000_000;
    localparam BAUDRATE = 115200;
    localparam SAMPLING = 16;
    localparam FIFO_DEPTH = 5;

    // ===== Camera Signals =====
    logic [ADDR_WIDTH-1:0] cam_wAddr;
    logic                  cam_we;
    logic [          15:0] cam_wData;

    // ===== VGA Signals =====
    logic [9:0] x_pixel, y_pixel;
    logic DE;
    logic v_sync, h_sync;

    // ===== Video Frame Buffer Signals =====
    logic [ADDR_WIDTH-1:0] video_rAddr;
    logic [          15:0] video_rData;
    logic [DATA_WIDTH-1:0] video_r, video_g, video_b;

    // ===== Capture Frame Buffer Signals =====
    logic [ADDR_WIDTH-1:0] capture_rAddr_vga;
    logic [          15:0] capture_rData_vga;
    logic [DATA_WIDTH-1:0] capture_r, capture_g, capture_b;

    // Capture Frame Buffer - UART read port
    logic                  uart_fb_re;
    logic [ADDR_WIDTH-1:0] uart_fb_rAddr;
    logic [          15:0] uart_fb_rData;

    // ===== Capture Control =====
    logic                  capture_enable;

    // ===== UART Signals =====
    logic                  b_tick;
    logic                  cap_send_trig;
    logic                  sending;
    logic                  tx_full;
    logic                  tx_busy;
    logic                  led_cap_reg;

    // ===== Pixel Clock =====
    logic                  pixel_clk;
    assign xclk = pixel_clk;

    // ===== LED Control =====
    always_ff @(posedge clk) begin
        if (reset) begin
            led_cap_reg <= 1'b0;
        end else begin
            if (cap_send_trig) begin
                led_cap_reg <= ~led_cap_reg;
            end
        end
    end

    assign led_capture = led_cap_reg;
    assign led_sending = sending;

    // =========================================================================
    // Capture Controller
    // =========================================================================
    Capture_Controller U_CAPTURE_CTRL (
        .clk           (clk),
        .reset         (reset),
        .pclk          (pclk),
        .cap_btn       (cap_btn),
        .vsync         (vsync),
        .capture_enable(capture_enable)
    );

    // =========================================================================
    // Pixel Clock Generator
    // =========================================================================
    Pixel_Clk_Gen U_PXL_CLK_GEN (
        .clk  (clk),
        .reset(reset),
        .pclk (pixel_clk)
    );

    // =========================================================================
    // VGA Sync Generator
    // =========================================================================
    VGA_Syncher U_VGA_SYNCHER (
        .clk    (pixel_clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    // =========================================================================
    // OV7670 Camera Interface
    // =========================================================================
    OV7670_Top #(
        .DATA_WIDTH (DATA_WIDTH),
        .IMG_WIDTH  (CAM_WIDTH),
        .IMG_HEIGHT (CAM_HEIGHT),
        .CROP_WIDTH (IMG_WIDTH),
        .CROP_HEIGHT(IMG_HEIGHT)
    ) U_OV7670_TOP (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA),
        .pclk (pclk),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (cam_we),
        .wAddr(cam_wAddr),
        .wData(cam_wData)
    );

    // =========================================================================
    // Video Frame Buffer (Left - Real-time)
    // =========================================================================
    Frame_Buffer #(
        .RGB_WIDTH (16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Video_Frame_Buffer (
        .wclk   (pclk),
        .we     (cam_we),
        .wAddr  (cam_wAddr),
        .wData  (cam_wData),
        // Port A: VGA
        .rclk_a (pixel_clk),
        .oe_a   (1'b1),
        .rAddr_a(video_rAddr),
        .rData_a(video_rData),
        // Port B: Not used
        .rclk_b (1'b0),
        .oe_b   (1'b0),
        .rAddr_b('0),
        .rData_b()
    );

    // =========================================================================
    // VGA Video Reader (Left)
    // =========================================================================
    VGA_Img_Reader #(
        .DATA_WIDTH(8),
        .RGB_WIDTH (16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .POSITION_X(0)
    ) U_VGA_Video_Reader (
        .clk    (pixel_clk),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (video_rAddr),
        .imgData(video_rData),
        .r_port (video_r),
        .g_port (video_g),
        .b_port (video_b)
    );

    // =========================================================================
    // Capture Frame Buffer (Right - Freeze + UART)
    // =========================================================================
    Frame_Buffer #(
        .RGB_WIDTH (16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Capture_Frame_Buffer (
        .wclk   (pclk),
        .we     (cam_we & capture_enable),
        .wAddr  (cam_wAddr),
        .wData  (cam_wData),
        // Port A: VGA
        .rclk_a (pixel_clk),
        .oe_a   (1'b1),
        .rAddr_a(capture_rAddr_vga),
        .rData_a(capture_rData_vga),
        // Port B: UART
        .rclk_b (clk),
        .oe_b   (uart_fb_re),
        .rAddr_b(uart_fb_rAddr),
        .rData_b(uart_fb_rData)
    );

    // =========================================================================
    // VGA Capture Reader (Right)
    // =========================================================================
    VGA_Img_Reader #(
        .DATA_WIDTH(8),
        .RGB_WIDTH (16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .POSITION_X(1)
    ) U_VGA_Capture_Reader (
        .clk    (pixel_clk),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (capture_rAddr_vga),
        .imgData(capture_rData_vga),
        .r_port (capture_r),
        .g_port (capture_g),
        .b_port (capture_b)
    );

    // =========================================================================
    // UART Baud Generator
    // =========================================================================
    UART_BAUD_GEN #(
        .CLK_FREQ(CLK_FREQ),
        .BAUDRATE(BAUDRATE),
        .SAMPLING(SAMPLING)
    ) U_UART_BAUD_GEN (
        .clk   (clk),
        .reset (reset),
        .b_tick(b_tick)
    );

    // =========================================================================
    // UART RX
    // =========================================================================
    UART_RX_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLING  (SAMPLING),
        .ADDR_WIDTH(FIFO_DEPTH)
    ) U_UART_RX_TOP (
        .clk          (clk),
        .reset        (reset),
        .b_tick       (b_tick),
        .rx           (rx),
        .rx_empty     (),
        .rx_full      (),
        .cap_send_trig(cap_send_trig)
    );

    // =========================================================================
    // UART TX
    // =========================================================================
    UART_TX_TOP #(
        .DATA_WIDTH   (DATA_WIDTH),
        .RGB_WIDTH    (RGB_WIDTH),
        .IMG_WIDTH    (IMG_WIDTH),
        .IMG_HEIGHT   (IMG_HEIGHT),
        .SAMPLING     (SAMPLING),
        .ADDR_WIDTH   (FIFO_DEPTH),
        .FB_ADDR_WIDTH(ADDR_WIDTH)
    ) U_UART_TX_TOP (
        .clk          (clk),
        .reset        (reset),
        .b_tick       (b_tick),
        .cap_send_trig(cap_send_trig),
        // Frame Buffer read
        .fb_re        (uart_fb_re),
        .fb_rAddr     (uart_fb_rAddr),
        .fb_rData     (uart_fb_rData),
        // UART output
        .tx_full      (tx_full),
        .tx_busy      (tx_busy),
        .sending      (sending),
        .tx           (tx)
    );

    // =========================================================================
    // HDMI Output
    // =========================================================================
    logic [23:0] vid_pData;

    rgb2dvi_0 u_hdmi (
        .TMDS_Clk_p (TMDS_Clk_p),
        .TMDS_Clk_n (TMDS_Clk_n),
        .TMDS_Data_p(TMDS_Data_p),
        .TMDS_Data_n(TMDS_Data_n),
        .aRst       (reset),
        .vid_pData  (vid_pData),
        .vid_pVDE   (DE),
        .vid_pHSync (h_sync),
        .vid_pVSync (v_sync),
        .PixelClk   (pixel_clk)
    );

    // =========================================================================
    // Output Mux
    // =========================================================================
    always_comb begin
        if (x_pixel < 320) begin
            vid_pData = {video_r, video_b, video_g};
        end else begin
            vid_pData = {capture_r, capture_b, capture_g};
        end
    end

endmodule
