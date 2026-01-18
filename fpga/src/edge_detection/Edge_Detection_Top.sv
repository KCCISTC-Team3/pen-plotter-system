`timescale 1ns / 1ps

module Edge_Detection_Top #(
    parameter WIDTH   = 8,
    parameter H_RES   = 80,
    parameter V_RES   = 120,
    parameter TH_HIGH = 240,
    parameter TH_LOW  = 120
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
    logic gray_vsync, gray_hsync, gray_de;
    logic [WIDTH-1:0] gray_data;

    logic gauss_vsync, gauss_hsync, gauss_de;
    logic [WIDTH-1:0] gauss_data;

    logic sobel_vsync, sobel_hsync, sobel_de;
    logic [WIDTH-1:0] sobel_data;

    logic canny_vsync, canny_hsync, canny_de;
    logic [WIDTH-1:0] canny_data;

    assign o_vsync = canny_vsync;
    assign o_hsync = canny_hsync;
    assign o_de    = canny_de;
    assign o_data  = canny_data;

    Grayscale #(
        .WIDTH(WIDTH)
    ) U_Grayscale (
        .clk     (clk),
        .rstn    (rstn),
        .i_vsync (i_vsync),
        .i_hsync (i_hsync),
        .i_de    (i_de),
        .i_r_data(i_r_data),
        .i_g_data(i_g_data),
        .i_b_data(i_b_data),
        .o_vsync (gray_vsync),
        .o_hsync (gray_hsync),
        .o_de    (gray_de),
        .o_data  (gray_data)
    );

    Gaussian_Blur #(
        .WIDTH(WIDTH),
        .H_RES(H_RES)
    ) U_Gaussian_Blur (
        .clk    (clk),
        .rstn   (rstn),
        .i_vsync(gray_vsync),
        .i_hsync(gray_hsync),
        .i_de   (gray_de),
        .i_data (gray_data),
        .o_vsync(gauss_vsync),
        .o_hsync(gauss_hsync),
        .o_de   (gauss_de),
        .o_data (gauss_data)
    );

    Sobel #(
        .WIDTH(WIDTH),
        .H_RES(H_RES)
    ) U_Sobel (
        .clk    (clk),
        .rstn   (rstn),
        .i_vsync(gauss_vsync),
        .i_hsync(gauss_hsync),
        .i_de   (gauss_de),
        .i_data (gauss_data),
        .o_vsync(sobel_vsync),
        .o_hsync(sobel_hsync),
        .o_de   (sobel_de),
        .o_data (sobel_data)
    );

    Canny #(
        .WIDTH  (WIDTH),
        .H_RES  (H_RES),
        // .V_RES  (V_RES),
        .TH_HIGH(TH_HIGH),
        .TH_LOW (TH_LOW)
    ) U_Canny (
        .clk    (clk),
        .rstn   (rstn),
        .i_vsync(gauss_vsync),
        .i_hsync(gauss_hsync),
        .i_de   (gauss_de),
        .i_data (gauss_data),
        .o_vsync(canny_vsync),
        .o_hsync(canny_hsync),
        .o_de   (canny_de),
        .o_data (canny_data)
    );

endmodule
