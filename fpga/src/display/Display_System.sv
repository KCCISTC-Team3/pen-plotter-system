`timescale 1ns / 1ps

module Display_System #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    // Clock & Reset
    input  logic clk,
    input  logic reset,
    output logic pixel_clk,

    // Video Frame Buffer Read
    output logic [ADDR_WIDTH-1:0] video_fb_rAddr,
    input  logic [          15:0] video_fb_rData,

    // Capture Frame Buffer Read
    output logic [ADDR_WIDTH-1:0] capture_fb_rAddr,
    input  logic [          15:0] capture_fb_rData,

    // HDMI TMDS Output
    output wire       TMDS_Clk_p,
    output wire       TMDS_Clk_n,
    output wire [2:0] TMDS_Data_p,
    output wire [2:0] TMDS_Data_n
);

    // ===== VGA Signals =====
    logic [9:0] x_pixel, y_pixel;
    logic DE, h_sync, v_sync;

    // ===== RGB Output =====
    logic [DATA_WIDTH-1:0] video_r, video_g, video_b;
    logic [DATA_WIDTH-1:0] capture_r, capture_g, capture_b;
    logic [23:0] vid_pData;

    // =========================================================================
    // Pixel Clock Generator (25MHz)
    // =========================================================================
    Pixel_Clk_Gen U_Pixel_Clk_Gen (
        .clk  (clk),
        .reset(reset),
        .pclk (pixel_clk)
    );

    // =========================================================================
    // VGA Sync Generator
    // =========================================================================
    VGA_Syncher U_VGA_Syncher (
        .clk    (pixel_clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    // =========================================================================
    // VGA Video Reader (Left Side - Real-time Camera)
    // =========================================================================
    VGA_Img_Reader #(
        .DATA_WIDTH(DATA_WIDTH),
        .RGB_WIDTH (16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .POSITION_X(0)
    ) U_VGA_Video_Reader (
        .clk    (pixel_clk),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (video_fb_rAddr),
        .imgData(video_fb_rData),
        .r_port (video_r),
        .g_port (video_g),
        .b_port (video_b)
    );

    // =========================================================================
    // VGA Capture Reader (Right Side - Frozen/Processed Image)
    // =========================================================================
    VGA_Img_Reader #(
        .DATA_WIDTH(DATA_WIDTH),
        .RGB_WIDTH (16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .POSITION_X(1)
    ) U_VGA_Capture_Reader (
        .clk    (pixel_clk),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (capture_fb_rAddr),
        .imgData(capture_fb_rData),
        .r_port (capture_r),
        .g_port (capture_g),
        .b_port (capture_b)
    );

    // =========================================================================
    // Output Multiplexer (Left: Video, Right: Capture)
    // =========================================================================
    always_comb begin
        if (x_pixel < 320) begin
            // vid_pData = {video_r, video_g, video_b};
            vid_pData = {capture_r, capture_g, capture_b};
        end else begin
            vid_pData = {capture_r, capture_g, capture_b};
        end
    end

    // =========================================================================
    // HDMI Output (RGB to DVI)
    // =========================================================================
    rgb2dvi_0 U_HDMI_Output (
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

endmodule
