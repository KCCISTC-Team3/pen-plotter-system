`timescale 1ns / 1ps

module UART_RX_Top #(
    parameter DATA_WIDTH      = 8,
    parameter FIFO_DEPTH      = 5,
    parameter IMG_WIDTH       = 170,
    parameter IMG_HEIGHT      = 240,
    parameter TOTAL_PIXELS    = IMG_WIDTH * IMG_HEIGHT,
    parameter PIXEL_CNT_WIDTH = $clog2(TOTAL_PIXELS)
) (
    input  logic                       clk,
    input  logic                       reset,
    input  logic                       rx,
    input                              cam_mode,    // 1: camera, 0: uart
    output logic [   3*DATA_WIDTH-1:0] rgb_data,
    output logic                       pixel_done,
    output logic [PIXEL_CNT_WIDTH-1:0] pixel_cnt,
    output logic                       frame_done
);
    logic [DATA_WIDTH-1:0] pop_data;
    logic                  empty;
    logic                  rx_done;

    UART_RX_FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) U_UART_RX_FIFO (
        .clk     (clk),
        .reset   (reset),
        .rx      (rx),
        .empty   (empty),
        .pop_data(pop_data),
        .rx_done (rx_done)
    );

    Data_Assembly_FSM #(
        .DATA_WIDTH     (DATA_WIDTH),
        .TOTAL_PIXELS   (TOTAL_PIXELS),
        .PIXEL_CNT_WIDTH(PIXEL_CNT_WIDTH)
    ) U_Data_Assembly_FSM (
        .clk       (clk),
        .reset     (reset),
        .empty     (empty),
        .pop_data  (pop_data),
        .cam_mode  (cam_mode),
        .rgb_data  (rgb_data),
        .pixel_done(pixel_done),
        .pixel_cnt (pixel_cnt),
        .frame_done(frame_done)
    );

endmodule
