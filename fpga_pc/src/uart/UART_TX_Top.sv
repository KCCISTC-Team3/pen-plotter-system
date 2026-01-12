`timescale 1ns / 1ps

module UART_TX_Top #(
    parameter DATA_WIDTH   = 8,
    parameter FIFO_DEPTH   = 5,
    parameter IMG_WIDTH    = 80,  // 176  
    parameter IMG_HEIGHT   = 120,  // 240
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT,
    parameter TOTAL_BYTES  = TOTAL_PIXELS >> 3,
    // parameter ADDR_WIDTH   = $clog2(TOTAL_BYTES),
    parameter ADDR_WIDTH   = $clog2(TOTAL_PIXELS)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  canny_de,
    input  logic [DATA_WIDTH-1:0] canny_data,
    output logic                  tx
);
    logic                  we;
    logic [DATA_WIDTH-1:0] wData;
    logic [ADDR_WIDTH-1:0] wAddr;
    logic                  frame_tick;
    logic [DATA_WIDTH-1:0] tx_data;
    logic                  tx_busy;
    logic                  tx_done;
    logic                  frame_done;
    logic                  b_tick;
    logic                  start_trig;

    Pixel_FSM #(
        .DATA_WIDTH  (DATA_WIDTH),
        .TOTAL_PIXELS(TOTAL_PIXELS),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) U_Pixel_FSM (
        .clk       (clk),
        .reset     (reset),
        .canny_de  (canny_de),
        .canny_data(canny_data),
        .we        (we),
        .wData     (wData),
        .wAddr     (wAddr),
        .frame_tick(frame_tick)
    );

    TX_RAM #(
        .DATA_WIDTH  (DATA_WIDTH),
        .TOTAL_PIXELS(TOTAL_PIXELS)
    ) U_TX_RAM (
        .clk       (clk),
        .reset     (reset),
        .we        (we),
        .wData     (wData),
        .wAddr     (wAddr),
        .frame_tick(frame_tick),
        .re        (frame_tick || tx_done),
        .rData     (tx_data),
        .frame_done(frame_done)
    );

    Tick_Gen_16 U_Tick_Gen (
        .clk     (clk),
        .reset   (reset),
        .b_16tick(b_tick)
    );

    UART_TX #(
        .DATA_WIDTH(DATA_WIDTH)
    ) U_UART_TX (
        .clk       (clk),
        .reset     (reset),
        .start_trig(start_trig),
        .tx_data   (tx_data),
        .b_16tick  (b_tick),
        .tx        (tx),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            start_trig <= 1'b0;
        end else begin
            start_trig <= frame_tick || ((~tx_busy && tx_done) && frame_done);
        end
    end

    // UART_TX_FIFO #(
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .FIFO_DEPTH(FIFO_DEPTH)
    // ) U_UART_TX_FIFO (
    //     .clk         (clk),
    //     .reset       (reset),
    //     .tx_data     (tx_data),
    //     .push        (frame_done && ~tx_fifo_full),
    //     .tx          (tx),
    //     .tx_fifo_full(tx_fifo_full)
    // );

endmodule
