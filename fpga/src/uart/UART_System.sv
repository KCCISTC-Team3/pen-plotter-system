`timescale 1ns / 1ps

module UART_System #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT),
    parameter CLK_FREQ   = 125_000_000,
    parameter BAUDRATE   = 115200,
    parameter SAMPLING   = 16,
    parameter FIFO_DEPTH = 5
) (
    // Clock & Reset
    input logic clk,
    input logic reset,

    // UART Interface
    input  logic rx,
    output logic tx,

    // Edge Frame Buffer Read (for TX)
    output logic                  edge_fb_re,
    output logic [ADDR_WIDTH-1:0] edge_fb_rAddr,
    input  logic [           7:0] edge_fb_rData,

    // PC Image Frame Buffer Write (from RX)
    output logic                  pc_img_fb_we,
    output logic [ADDR_WIDTH-1:0] pc_img_fb_wAddr,
    output logic [          15:0] pc_img_fb_wData,

    // Command & Mode Control
    output logic start_edge_trig,
    output logic edge_input_sel,

    // Control & Status
    input  logic edge_tx_trig,
    output logic sending,
    output logic receiving
);

    // ===== Baud Tick =====
    logic b_tick;

    // ===== TX Status =====
    logic tx_full, tx_busy;

    // ===== TX Done =====
    logic frame_tx_done;

    // =========================================================================
    // UART Baud Generator
    // =========================================================================
    UART_BAUD_GEN #(
        .CLK_FREQ(CLK_FREQ),
        .BAUDRATE(BAUDRATE),
        .SAMPLING(SAMPLING)
    ) U_UART_Baud_Generator (
        .clk   (clk),
        .reset (reset),
        .b_tick(b_tick)
    );

    // =========================================================================
    // UART RX (Command + Image Receiver)
    // =========================================================================
    UART_RX_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SAMPLING  (SAMPLING),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) U_UART_RX (
        .clk            (clk),
        .reset          (reset),
        .b_tick         (b_tick),
        .rx             (rx),
        .start_edge_trig(start_edge_trig),
        .edge_input_sel (edge_input_sel),
        .frame_tx_done  (frame_tx_done),
        .pc_img_fb_we   (pc_img_fb_we),
        .pc_img_fb_wAddr(pc_img_fb_wAddr),
        .pc_img_fb_wData(pc_img_fb_wData),
        .receiving      (receiving)
    );

    // =========================================================================
    // UART TX (Image Transmitter)
    // =========================================================================
    UART_TX_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .SAMPLING  (SAMPLING),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) U_UART_TX (
        .clk          (clk),
        .reset        (reset),
        .b_tick       (b_tick),
        .edge_tx_trig (edge_tx_trig),
        .fb_re        (edge_fb_re),
        .fb_rAddr     (edge_fb_rAddr),
        .fb_rData     (edge_fb_rData),
        .frame_tx_done(frame_tx_done),
        .tx_full      (tx_full),
        .tx_busy      (tx_busy),
        .sending      (sending),
        .tx           (tx)
    );

endmodule
