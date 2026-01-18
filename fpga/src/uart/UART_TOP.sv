`timescale 1ns / 1ps

module UART_TOP (
    input  logic clk,
    input  logic reset,
    input  logic rx,
    output logic tx,
    output logic led_capture,
    output logic led_sending
);
    parameter CLK_FREQ = 125_000_000;
    parameter BAUDRATE = 115200;
    parameter SAMPLING = 16;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 5;

    logic b_tick;
    logic cap_send_trig;
    logic sending;
    logic tx_full;
    logic tx_busy;
    
    logic led_cap_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            led_cap_reg <= 1'b0;
        end else begin
            if (cap_send_trig) begin
                led_cap_reg <= ~led_cap_reg;
            end
        end
    end

    assign led_capture = led_cap_reg;
    assign led_sending = sending;

    UART_BAUD_GEN #(
        .CLK_FREQ(CLK_FREQ),
        .BAUDRATE(BAUDRATE),
        .SAMPLING(SAMPLING)
    ) U_UART_BAUD_GEN (
        .clk   (clk),
        .reset (reset),
        .b_tick(b_tick)
    );

    UART_RX_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLING  (SAMPLING),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_UART_RX_TOP (
        .clk          (clk),
        .reset        (reset),
        .b_tick       (b_tick),
        .rx           (rx),
        .rx_empty     (),
        .rx_full      (),
        .cap_send_trig(cap_send_trig)
    );

    UART_TX_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLING  (SAMPLING),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_UART_TX_TOP (
        .clk          (clk),
        .reset        (reset),
        .b_tick       (b_tick),
        .cap_send_trig(cap_send_trig),
        .tx_full      (tx_full),
        .tx_busy      (tx_busy),
        .sending      (sending),
        .tx           (tx)
    );

endmodule