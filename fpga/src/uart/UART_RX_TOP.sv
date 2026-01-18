`timescale 1ns / 1ps

module UART_RX_TOP #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT),
    parameter SAMPLING   = 16,
    parameter FIFO_DEPTH = 5
) (
    input logic clk,
    input logic reset,
    input logic b_tick,
    input logic rx,

    // Command & Mode Control
    output logic start_edge_trig,
    output logic edge_input_sel,   // 0: Camera, 1: PC

    // TX Done signal
    input logic frame_tx_done,

    // PC Image FB write
    output logic                  pc_img_fb_we,
    output logic [ADDR_WIDTH-1:0] pc_img_fb_wAddr,
    output logic [          15:0] pc_img_fb_wData,

    // Status
    output logic receiving
);

    logic [DATA_WIDTH-1:0] rx_data;
    logic                  rx_done;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  rx_empty;
    logic                  rx_full;

    // =========================================================================
    // UART RX Core
    // =========================================================================
    UART_RX #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLING  (SAMPLING)
    ) U_UART_RX (
        .clk    (clk),
        .reset  (reset),
        .b_tick (b_tick),
        .rx     (rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // =========================================================================
    // RX FIFO
    // =========================================================================
    FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(FIFO_DEPTH)
    ) U_RX_FIFO (
        .clk      (clk),
        .reset    (reset),
        .push     (rx_done),
        .push_data(rx_data),
        .pop      (rd_en),
        .pop_data (rd_data),
        .full     (rx_full),
        .empty    (rx_empty)
    );

    // =========================================================================
    // UART RX Command & Image Receiver
    // =========================================================================
    UART_RX_CMD #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_UART_RX_CMD (
        .clk            (clk),
        .reset          (reset),
        .rd_en          (rd_en),
        .rx_data        (rd_data),
        .rx_empty       (rx_empty),
        .start_edge_trig(start_edge_trig),
        .edge_input_sel (edge_input_sel),
        .frame_tx_done  (frame_tx_done),
        .pc_img_fb_we   (pc_img_fb_we),
        .pc_img_fb_wAddr(pc_img_fb_wAddr),
        .pc_img_fb_wData(pc_img_fb_wData),
        .receiving      (receiving)
    );

endmodule
