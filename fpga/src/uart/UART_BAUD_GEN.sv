`timescale 1ns / 1ps

module UART_BAUD_GEN #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUDRATE = 9600,
    parameter SAMPLING = 16
) (
    input  logic clk,
    input  logic reset,
    output logic b_tick
);

    localparam BAUD_COUNT = CLK_FREQ / (BAUDRATE * SAMPLING);

    logic [$clog2(BAUD_COUNT)-1:0] counter_reg, counter_next;
    logic tick_reg, tick_next;

    assign b_tick = tick_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            tick_reg    <= 0;
        end else begin
            counter_reg <= counter_next;
            tick_reg    <= tick_next;
        end
    end

    always_comb begin
        counter_next = counter_reg;
        tick_next    = 1'b0;
        if (counter_reg >= BAUD_COUNT - 1) begin
            counter_next = 0;
            tick_next    = 1'b1;
        end else begin
            counter_next = counter_reg + 1;
            tick_next    = 1'b0;
        end
    end

endmodule
