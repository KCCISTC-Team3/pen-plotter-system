`timescale 1ns / 1ps

module Camera_System #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter CAM_WIDTH  = 320,
    parameter CAM_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    // Clock & Reset
    input logic clk,
    input logic reset,
    input logic pclk,

    // OV7670 Camera Interface
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    output tri         SCL,
    inout  tri         SDA,

    // Capture Control
    input logic cap_btn,

    // Video Frame Buffer (Real-time) - VGA Read Port
    input  logic                  vga_clk,
    input  logic [ADDR_WIDTH-1:0] video_fb_rAddr,
    output logic [          15:0] video_fb_rData,

    // Capture Frame Buffer (Freeze) - VGA Read Port
    input  logic [ADDR_WIDTH-1:0] capture_fb_rAddr_vga,
    output logic [          15:0] capture_fb_rData_vga,

    // Capture Frame Buffer - Edge Read Port
    input  logic                  capture_fb_re_edge,
    input  logic [ADDR_WIDTH-1:0] capture_fb_rAddr_edge,
    output logic [          15:0] capture_fb_rData_edge,

    // PC Image Frame Buffer - Edge Read Port
    input  logic                  pc_img_fb_re,
    input  logic [ADDR_WIDTH-1:0] pc_img_fb_rAddr,
    output logic [          15:0] pc_img_fb_rData,

    // PC Image Frame Buffer - UART Write Port
    input logic                  pc_img_fb_we,
    input logic [ADDR_WIDTH-1:0] pc_img_fb_wAddr,
    input logic [          15:0] pc_img_fb_wData
);

    // ===== Internal Signals =====
    logic                  capture_enable;
    logic [ADDR_WIDTH-1:0] cam_wAddr;
    logic                  cam_we;
    logic [          15:0] cam_wData;

    // =========================================================================
    // Capture Controller
    // =========================================================================
    Capture_Controller U_Capture_Controller (
        .clk           (clk),
        .reset         (reset),
        .pclk          (pclk),
        .cap_btn       (cap_btn),
        .vsync         (vsync),
        .capture_enable(capture_enable)
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
    // Video Frame Buffer (Real-time Camera Feed)
    // =========================================================================
    Frame_Buffer #(
        .DATA_WIDTH(16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Video_FB (
        .wclk   (pclk),
        .we     (cam_we),
        .wAddr  (cam_wAddr),
        .wData  (cam_wData),
        // Port A: VGA
        .rclk_a (vga_clk),
        .oe_a   (1'b1),
        .rAddr_a(video_fb_rAddr),
        .rData_a(video_fb_rData),
        // Port B: Not used
        .rclk_b (1'b0),
        .oe_b   (1'b0),
        .rAddr_b('0),
        .rData_b()
    );

    // =========================================================================
    // Capture Frame Buffer (Frozen Camera Image)
    // =========================================================================
    Frame_Buffer #(
        .DATA_WIDTH(16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Capture_FB (
        .wclk   (pclk),
        .we     (cam_we & capture_enable),
        .wAddr  (cam_wAddr),
        .wData  (cam_wData),
        // Port A: VGA
        .rclk_a (vga_clk),
        .oe_a   (1'b1),
        .rAddr_a(capture_fb_rAddr_vga),
        .rData_a(capture_fb_rData_vga),
        // Port B: Edge Controller
        .rclk_b (clk),
        .oe_b   (capture_fb_re_edge),
        .rAddr_b(capture_fb_rAddr_edge),
        .rData_b(capture_fb_rData_edge)
    );

    // =========================================================================
    // PC Image Frame Buffer (UART Received Image)
    // =========================================================================
    Frame_Buffer #(
        .DATA_WIDTH(16),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_PC_Image_FB (
        .wclk   (clk),
        .we     (pc_img_fb_we),
        .wAddr  (pc_img_fb_wAddr),
        .wData  (pc_img_fb_wData),
        // Port A: Edge Controller
        .rclk_a (clk),
        .oe_a   (pc_img_fb_re),
        .rAddr_a(pc_img_fb_rAddr),
        .rData_a(pc_img_fb_rData),
        // Port B: Not used
        .rclk_b (1'b0),
        .oe_b   (1'b0),
        .rAddr_b('0),
        .rData_b()
    );

endmodule
