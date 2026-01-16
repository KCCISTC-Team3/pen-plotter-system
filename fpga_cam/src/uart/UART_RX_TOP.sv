`timescale 1ns / 1ps

module UART_RX_TOP #(
    parameter DATA_WIDTH = 8,
    parameter SAMPLING   = 16,
    parameter ADDR_WIDTH = 5
) (
    input  logic clk,
    input  logic reset,
    input  logic b_tick,
    input  logic rx,
    output logic rx_empty,
    output logic rx_full,
    output logic cap_send_trig
);

    logic [DATA_WIDTH-1:0] rx_data;
    logic                  rx_done;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;

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

    FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
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

    UART_RX_CMD #(
        .DATA_WIDTH(DATA_WIDTH)
    ) U_UART_RX_CMD (
        .clk          (clk),
        .reset        (reset),
        .rx_empty     (rx_empty),
        .rx_data      (rd_data),
        .rd_en        (rd_en),
        .cap_send_trig(cap_send_trig)
    );

endmodule
