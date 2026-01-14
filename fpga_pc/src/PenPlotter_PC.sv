`timescale 1ns / 1ps

module PenPlotter_PC (
    input  logic clk,
    input  logic reset,
    input  logic rx,
    output logic tx
);
    localparam DATA_WIDTH = 8;
    localparam RGB_WIDTH = DATA_WIDTH * 3;
    localparam FIFO_DEPTH = 5;
    localparam IMG_WIDTH = 176;    //176
    localparam IMG_HEIGHT = 240;   //240
    localparam TH_HIGH = 240;
    localparam TH_LOW = 120;

    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam ADDR_WIDTH = $clog2(TOTAL_PIXELS);

    logic                  frame_done_delayed;
    logic                  oe;

    logic [ RGB_WIDTH-1:0] wData;

    logic [ADDR_WIDTH-1:0] wAddr;
    logic                  we;

    logic [ADDR_WIDTH-1:0] read_addr;
    logic [ RGB_WIDTH-1:0] read_img_data;
    logic                  DE;

    logic [DATA_WIDTH-1:0] o_r, o_g, o_b;

    logic                  canny_de;
    logic [DATA_WIDTH-1:0] canny_data;

    logic                  frame_done;

    UART_RX_Top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_UART_RX_Top (
        .clk       (clk),
        .reset     (reset),
        .rx        (rx),
        .cam_mode  (1'b0),  // 0: PC, 1: Camera 
        .rgb_data  (wData),
        .pixel_done(we),
        .pixel_cnt (wAddr),
        .frame_done(frame_done)
    );

    RX_RAM #(
        .RGB_WIDTH (RGB_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_RX_RAM (
        .clk         (clk),
        .we          (we),
        .wData       (wData),
        .wAddr       (wAddr),
        .frame_done  (frame_done),
        .o_frame_done(frame_done_delayed),
        .oe          (oe),
        .rAddr       (read_addr),
        .imgData     (read_img_data)
    );

    Edge_Detection_Top #(
        .WIDTH  (DATA_WIDTH),
        .H_RES  (IMG_WIDTH),
        .TH_HIGH(TH_HIGH),
        .TH_LOW (TH_LOW)
    ) U_Edge_Detection_Top (
        .clk     (clk),
        .rstn    (~reset),
        .i_vsync (1'b0),
        .i_hsync (1'b0),
        .i_de    (DE),
        .i_r_data(o_r),
        .i_g_data(o_g),
        .i_b_data(o_b),
        .o_vsync (),
        .o_hsync (),
        .o_de    (canny_de),
        .o_data  (canny_data)
    );

    Img_Reader #(
        .RGB_WIDTH (RGB_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Img_Reader (
        .clk       (clk),
        .reset     (reset),
        .start_read(frame_done_delayed),
        .img       (read_img_data),
        .addr      (read_addr),
        .re        (oe),
        .o_de      (DE),
        .r_port    (o_r),
        .g_port    (o_g),
        .b_port    (o_b)
    );

    UART_TX_Top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_UART_TX_Top (
        .clk       (clk),
        .reset     (reset),
        .canny_de  (canny_de),
        .canny_data(canny_data),
        .tx        (tx)
    );

endmodule
