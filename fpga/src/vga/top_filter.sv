`timescale 1ns / 1ps

module top_filter #(
    parameter WIDTH = 8,
    parameter H_RES = 170,
    parameter BRIGHTNESS_ADD = 30,
    parameter BRIGHTNESS_SUB = 30,
    parameter TH_HIGH = 230,
    parameter TH_LOW = 180
) (
    input  logic             clk,
    input  logic             rstn,
    input  logic             i_vsync,
    input  logic             i_hsync,
    input  logic             i_de,
    input  logic [WIDTH-1:0] i_r_data,
    input  logic [WIDTH-1:0] i_g_data,
    input  logic [WIDTH-1:0] i_b_data,
    output logic             o_vsync,
    output logic             o_hsync,
    output logic             o_de,
    output logic [WIDTH-1:0] o_data
);
    logic       gray_vsync;
    logic       gray_hsync;
    logic       gray_de;
    logic [7:0] gray_data;

    logic       gauss_vsync;
    logic       gauss_hsync;
    logic       gauss_de;
    logic [7:0] gauss_data;

    logic       sobel_vsync;
    logic       sobel_hsync;
    logic       sobel_de;
    logic [7:0] sobel_data;

    logic       canny_vsync;
    logic       canny_hsync;
    logic       canny_de;
    logic [7:0] canny_data;

    assign o_vsync = canny_vsync;
    assign o_hsync = canny_hsync;
    assign o_de    = canny_de;
    assign o_data  = canny_data;

    DS_Gray #(
        .WIDTH(8),
        .BRIGHTNESS_ADD(0),
        .BRIGHTNESS_SUB(0)
    ) U_DS_Gray (
        .clk(clk),
        .rstn(rstn),
        .i_vsync(i_vsync),
        .i_hsync(i_hsync),
        .i_de(i_de),
        .i_r_data(i_r_data),
        .i_g_data(i_g_data),
        .i_b_data(i_b_data),
        .o_vsync(gray_vsync),
        .o_hsync(gray_hsync),
        .o_de(gray_de),  // 1clk delay
        .o_data(gray_data)
    );

    Gaussian #(
        .WIDTH(8),
        .H_RES(170)
    ) U_Gaussian (
        .clk(clk),
        .rstn(rstn),
        .i_vsync(gray_vsync),
        .i_hsync(gray_hsync),
        .i_de(gray_de),
        .i_data(gray_data),
        .o_vsync(gauss_vsync),
        .o_hsync(gauss_hsync),
        .o_de(gauss_de),  // 2clk delay
        .o_data(gauss_data)
    );

    Sobel #(
        .WIDTH(8),
        .H_RES(170)
    ) U_Sobel (
        .clk(clk),
        .rstn(rstn),
        .i_vsync(gauss_vsync),
        .i_hsync(gauss_hsync),
        .i_de(gauss_de),
        .i_data(gauss_data),
        .o_vsync(sobel_vsync),
        .o_hsync(sobel_hsync),
        .o_de(sobel_de),  // 3clk delay
        .o_data(sobel_data)
    );

    Canny_Edge #(
        .WIDTH  (8),
        .H_RES  (170),
        .TH_HIGH(255),
        .TH_LOW (250)
    ) U_Canny_Edge (
        .clk(clk),
        .rstn(rstn),
        .i_vsync(sobel_vsync),
        .i_hsync(sobel_hsync),
        .i_de(sobel_de),
        .i_data(sobel_data),
        .o_vsync(canny_vsync),
        .o_hsync(canny_hsync),
        .o_de(canny_de),  // 350clk delay
        .o_data(canny_data)
    );

endmodule
