`timescale 1ns / 1ps

module PenPlotter_Camera (
    input  logic       clk,
    input  logic       reset,
    // OV7670 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    // vga port
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    // I2C
    output tri         SCL,
    inout  tri         SDA,
    // Button
    input  logic       cap_btn,
    input  logic       send_btn
);
    localparam DATA_WIDTH = 8;
    localparam RGB_WIDTH = DATA_WIDTH * 3;
    localparam IMG_WIDTH = 176;
    localparam IMG_HEIGHT = 240;
    localparam CAM_WIDTH = 320;
    localparam CAM_HEIGHT = 240;

    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam ADDR_WIDTH = $clog2(TOTAL_PIXELS);

    // Camera signals
    logic [ADDR_WIDTH-1:0] cam_wAddr;
    logic                  cam_we;
    logic [          15:0] cam_wData;

    // VGA signals
    logic [9:0] x_pixel, y_pixel;
    logic                  DE;

    // Video (left) Frame Buffer signals
    logic [ADDR_WIDTH-1:0] video_rAddr;
    logic [          15:0] video_rData;
    logic [DATA_WIDTH-1:0] video_r, video_g, video_b;

    // Capture (right) Frame Buffer signals
    logic [ADDR_WIDTH-1:0] capture_rAddr;
    logic [15:0] capture_rData;
    logic [DATA_WIDTH-1:0] capture_r, capture_g, capture_b;

    // Capture enable signal
    logic capture_enable;

    // Pixel clock
    logic pixel_clk;

    assign xclk = pixel_clk;

    // =========================================================================
    // Capture Controller Module
    // =========================================================================
    Capture_Controller U_CAPTURE_CTRL (
        .clk            (clk),
        .reset          (reset),
        .pclk           (pclk),
        .cap_btn        (cap_btn),
        .vsync          (vsync),
        .capture_enable (capture_enable)
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
        .RGB_WIDTH (RGB_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Video_Frame_Buffer (
        .wclk (pclk),
        .we   (cam_we),
        .wAddr(cam_wAddr),
        .wData(cam_wData),
        .rclk (pixel_clk),
        .oe   (1'b1),
        .rAddr(video_rAddr),
        .rData(video_rData)
    );

    // =========================================================================
    // VGA Video Reader (Left)
    // =========================================================================
    VGA_Img_Reader #(
        // .DATA_WIDTH(DATA_WIDTH),
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
    // Capture Frame Buffer (Right - Freeze)
    // =========================================================================
    Frame_Buffer #(
        .RGB_WIDTH (RGB_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Capture_Frame_Buffer (
        .wclk (pclk),
        .we   (cam_we & capture_enable),
        .wAddr(cam_wAddr),
        .wData(cam_wData),
        .rclk (pixel_clk),
        .oe   (1'b1),
        .rAddr(capture_rAddr),
        .rData(capture_rData)
    );

    // =========================================================================
    // VGA Capture Reader (Right)
    // =========================================================================
    VGA_Img_Reader #(
        // .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .POSITION_X(1)
    ) U_VGA_Capture_Reader (
        .clk    (pixel_clk),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (capture_rAddr),
        .imgData(capture_rData),
        .r_port (capture_r),
        .g_port (capture_g),
        .b_port (capture_b)
    );

    // =========================================================================
    // VGA Output Mux
    // =========================================================================
    always_comb begin
        if (x_pixel < 320) begin
            r_port = video_r[7:4];
            g_port = video_g[7:4];
            b_port = video_b[7:4];
        end else begin
            r_port = capture_r[7:4];
            g_port = capture_g[7:4];
            b_port = capture_b[7:4];
        end
    end

endmodule

// =========================================================================
// Capture Controller Module
// Handles button debounce, CDC, and capture state machine
// =========================================================================
module Capture_Controller (
    input  logic clk,            // System clock
    input  logic reset,
    input  logic pclk,           // Pixel clock (camera domain)
    input  logic cap_btn,        // Capture button input
    input  logic vsync,          // Camera vsync signal
    output logic capture_enable  // Capture enable output (pclk domain)
);

    // Button debounce
    logic cap_btn_debounced;
    Button_Debounce #(.SIZE(16)) U_BTN_DB (
        .clk(clk), .reset(reset), .btn_in(cap_btn), .btn_out(cap_btn_debounced)
    );

    // clk domain signals
    logic capture_request;
    logic capture_done_synced;

    // pclk domain signals
    logic capture_request_sync1, capture_request_sync2;
    logic capture_request_synced;
    logic capture_pending;
    logic capture_done;
    logic vsync_prev;
    logic vsync_falling;

    // CDC: pclk -> clk (capture done feedback)
    logic capture_done_sync1, capture_done_sync2;

    // =========================================================================
    // Capture Request Level Signal (clk domain)
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            capture_request <= 1'b0;
        end else begin
            if (cap_btn_debounced) begin
                capture_request <= 1'b1;
            end else if (capture_done_synced) begin
                capture_request <= 1'b0;
            end
        end
    end

    // =========================================================================
    // CDC: clk -> pclk (Double FF Synchronizer)
    // =========================================================================
    always_ff @(posedge pclk) begin
        if (reset) begin
            capture_request_sync1 <= 1'b0;
            capture_request_sync2 <= 1'b0;
        end else begin
            capture_request_sync1 <= capture_request;
            capture_request_sync2 <= capture_request_sync1;
        end
    end

    assign capture_request_synced = capture_request_sync2;

    // =========================================================================
    // CDC: pclk -> clk (capture done feedback)
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            capture_done_sync1 <= 1'b0;
            capture_done_sync2 <= 1'b0;
        end else begin
            capture_done_sync1 <= capture_done;
            capture_done_sync2 <= capture_done_sync1;
        end
    end

    assign capture_done_synced = capture_done_sync2;

    // =========================================================================
    // Vsync Falling Edge Detection (pclk domain)
    // =========================================================================
    always_ff @(posedge pclk) begin
        if (reset) begin
            vsync_prev    <= 1'b1;
            vsync_falling <= 1'b0;
        end else begin
            vsync_prev    <= vsync;
            vsync_falling <= ~vsync & vsync_prev;
        end
    end

    // =========================================================================
    // Capture State Machine (pclk domain)
    // IDLE -> PENDING -> CAPTURING -> IDLE
    // =========================================================================
    always_ff @(posedge pclk) begin
        if (reset) begin
            capture_pending <= 1'b0;
            capture_enable  <= 1'b0;
            capture_done    <= 1'b0;
        end else begin
            capture_done <= 1'b0;
            if (capture_request_synced && !capture_pending && !capture_enable) begin
                capture_pending <= 1'b1;
            end else if (vsync_falling && capture_pending) begin
                capture_enable  <= 1'b1;
                capture_pending <= 1'b0;
            end else if (vsync_falling && capture_enable) begin
                capture_enable <= 1'b0;
                capture_done   <= 1'b1;
            end else if (!capture_request_synced && capture_pending) begin
                capture_pending <= 1'b0;
            end
        end
    end

endmodule