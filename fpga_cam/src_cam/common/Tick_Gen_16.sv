`timescale 1ns / 1ps

module Tick_Gen_16 (
    input  logic clk,
    input  logic reset,
    output logic b_16tick
);

    parameter BAUDRATE = 115200 * 16;
    localparam BAUD_COUNT = 100_000_000 / BAUDRATE;
    logic [$clog2(BAUD_COUNT)-1 : 0] count_reg, count_next;
    logic tick_reg, tick_next;

    assign b_16tick = tick_reg;

    always @(posedge clk) begin
        if (reset) begin
            count_reg <= 0;
            tick_reg  <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg  <= tick_next;
        end
    end

    always @(*) begin
        count_next = count_reg;
        tick_next  = 1'b0;
        if (count_reg == BAUD_COUNT - 1) begin
            count_next = 0;
            tick_next  = 1'b1;
        end else begin
            count_next = count_reg + 1;
            tick_next  = 1'b0;
        end
    end

endmodule
