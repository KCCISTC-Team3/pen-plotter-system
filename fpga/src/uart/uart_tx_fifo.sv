`timescale 1ns / 1ps

module UART_TX_FIFO #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 5
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic [DATA_WIDTH-1:0] tx_data,
    input  logic                  push,
    output logic                  tx,
    output logic                  tx_fifo_full
);
    logic                  b_tick;
    logic [DATA_WIDTH-1:0] fifo_tx_data;
    logic                  fifo_empty;
    logic                  tx_busy;
    logic                  tx_done;
    logic                  tx_start_cond;
    logic                  tx_start_d;
    logic                  tx_start_pulse;
    logic                  tx_pop_pulse;

    assign tx_start_cond = (~fifo_empty) & (~tx_busy);

    always_ff @(posedge clk) begin
        if (reset) tx_start_d <= 1'b0;
        else tx_start_d <= tx_start_cond;
    end

    assign tx_start_pulse = tx_start_d;
    assign tx_pop_pulse   = tx_start_cond;

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
        .b_16tick  (b_tick),
        .start_trig(tx_start_pulse),
        .tx_data   (fifo_tx_data),
        .tx        (tx),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(FIFO_DEPTH)
    ) U_TX_FIFO (
        .clk      (clk),
        .reset    (reset),
        .push_data(tx_data),
        .push     (push),
        .pop      (tx_pop_pulse),
        .pop_data (fifo_tx_data),
        .full     (tx_fifo_full),
        .empty    (fifo_empty)
    );

endmodule
