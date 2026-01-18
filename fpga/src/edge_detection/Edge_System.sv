`timescale 1ns / 1ps

module Edge_System #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT),
    parameter TH_HIGH    = 40,
    parameter TH_LOW     = 20
) (
    // Clock & Reset
    input logic clk,
    input logic reset,

    // Mode & Trigger Control
    input logic edge_input_sel,  // 0: Camera, 1: PC
    input logic start_edge_trig,

    // Status
    output logic edge_done,
    output logic processing,

    // Capture Frame Buffer Read (Camera Mode)
    output logic                  capture_fb_re,
    output logic [ADDR_WIDTH-1:0] capture_fb_rAddr,
    input  logic [          15:0] capture_fb_rData,

    // PC Image Frame Buffer Read (PC Mode)
    output logic                  pc_img_fb_re,
    output logic [ADDR_WIDTH-1:0] pc_img_fb_rAddr,
    input  logic [          15:0] pc_img_fb_rData,

    // Edge Result Frame Buffer Read (for UART TX)
    input  logic                  edge_fb_re,
    input  logic [ADDR_WIDTH-1:0] edge_fb_rAddr,
    output logic [           7:0] edge_fb_rData
);

    // ===== Edge Controller Signals =====
    logic edge_vsync, edge_hsync, edge_de;
    logic [7:0] edge_r, edge_g, edge_b;

    // ===== Edge Detection Output =====
    logic edge_o_vsync, edge_o_hsync, edge_o_de;
    logic [           7:0] edge_o_data;

    // ===== Edge Frame Buffer Write =====
    logic                  edge_fb_we;
    logic [ADDR_WIDTH-1:0] edge_fb_wAddr;
    logic [           7:0] edge_fb_wData;

    // ===== Input MUX Signals =====
    logic                  input_fb_re;
    logic [ADDR_WIDTH-1:0] input_fb_rAddr;
    logic [          15:0] input_fb_rData;

    // =========================================================================
    // Input Multiplexer (Camera vs PC Image)
    // =========================================================================
    always_comb begin
        if (edge_input_sel) begin  // PC Mode
            pc_img_fb_re     = input_fb_re;
            pc_img_fb_rAddr  = input_fb_rAddr;
            input_fb_rData   = pc_img_fb_rData;
            capture_fb_re    = 1'b0;
            capture_fb_rAddr = '0;
        end else begin  // Camera Mode
            capture_fb_re    = input_fb_re;
            capture_fb_rAddr = input_fb_rAddr;
            input_fb_rData   = capture_fb_rData;
            pc_img_fb_re     = 1'b0;
            pc_img_fb_rAddr  = '0;
        end
    end

    // =========================================================================
    // Edge Controller
    // =========================================================================
    Edge_Controller #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_Edge_Controller (
        .clk            (clk),
        .reset          (reset),
        .start_edge_trig(start_edge_trig),
        .edge_done      (edge_done),
        .processing     (processing),
        // Input FB read (MUXed)
        .cap_fb_re      (input_fb_re),
        .cap_fb_rAddr   (input_fb_rAddr),
        .cap_fb_rData   (input_fb_rData),
        // Edge FB write
        .edge_fb_we     (edge_fb_we),
        .edge_fb_wAddr  (edge_fb_wAddr),
        .edge_fb_wData  (edge_fb_wData),
        // Edge Detection interface
        .edge_vsync     (edge_vsync),
        .edge_hsync     (edge_hsync),
        .edge_de        (edge_de),
        .edge_r         (edge_r),
        .edge_g         (edge_g),
        .edge_b         (edge_b),
        .edge_o_vsync   (edge_o_vsync),
        .edge_o_hsync   (edge_o_hsync),
        .edge_o_de      (edge_o_de),
        .edge_o_data    (edge_o_data)
    );

    // =========================================================================
    // Edge Detection Pipeline
    // =========================================================================
    Edge_Detection_Top #(
        .WIDTH  (DATA_WIDTH),
        .H_RES  (IMG_WIDTH),
        .V_RES  (IMG_HEIGHT),
        .TH_HIGH(TH_HIGH),
        .TH_LOW (TH_LOW)
    ) U_Edge_Detection_Top (
        .clk     (clk),
        .rstn    (~reset),
        .i_vsync (edge_vsync),
        .i_hsync (edge_hsync),
        .i_de    (edge_de),
        .i_r_data(edge_r),
        .i_g_data(edge_g),
        .i_b_data(edge_b),
        .o_vsync (edge_o_vsync),
        .o_hsync (edge_o_hsync),
        .o_de    (edge_o_de),
        .o_data  (edge_o_data)
    );

    // =========================================================================
    // Edge Result Frame Buffer
    // =========================================================================
    Frame_Buffer #(
        .DATA_WIDTH(8),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Edge_Result_FB (
        .wclk   (clk),
        .we     (edge_fb_we),
        .wAddr  (edge_fb_wAddr),
        .wData  (edge_fb_wData),
        // Port A: UART TX
        .rclk_a (clk),
        .oe_a   (edge_fb_re),
        .rAddr_a(edge_fb_rAddr),
        .rData_a(edge_fb_rData),
        // Port B: Not used
        .rclk_b (1'b0),
        .oe_b   (1'b0),
        .rAddr_b('0),
        .rData_b()
    );

endmodule
