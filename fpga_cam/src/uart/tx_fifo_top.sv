`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/12 15:47:19
// Design Name: 
// Module Name: tx_fifo_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////




module UART_TX_FIFO #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 3
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

    

    assign tx_start_pulse = tx_start_cond;
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


module UART_TX #(
    parameter DATA_WIDTH = 8
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  start_trig,
    input  logic [DATA_WIDTH-1:0] tx_data,
    input  logic                  b_16tick,
    output logic                  tx,
    output logic                  tx_busy,
    output logic                  tx_done
);
    localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    logic [1:0] state, state_next;

    logic tx_reg, tx_next;
    logic tx_done_reg, tx_done_next;
    logic tx_busy_reg, tx_busy_next;

    logic [3:0] tick_cnt_reg, tick_cnt_next;
    logic [2:0] data_cnt_reg, data_cnt_next;

    logic [DATA_WIDTH-1:0] tx_data_buf, tx_data_next;

    assign tx      = tx_reg;
    assign tx_busy = tx_busy_reg;
    assign tx_done = tx_done_reg;
    

    always_ff @(posedge clk) begin
        if (reset) begin
            state        <= IDLE;
            tx_reg       <= 1'b1;
            tx_done_reg  <= 1'b0;
            tx_busy_reg  <= 1'b0;
            data_cnt_reg <= '0;
            tick_cnt_reg <= '0;
            tx_data_buf  <= '0;
        end else begin
            state        <= state_next;
            tx_reg       <= tx_next;
            tx_done_reg  <= tx_done_next;
            tx_busy_reg  <= tx_busy_next;
            data_cnt_reg <= data_cnt_next;
            tick_cnt_reg <= tick_cnt_next;
            tx_data_buf  <= tx_data_next;
        end
    end

    always_comb begin
        state_next    = state;
        tx_next       = tx_reg;
        tx_done_next  = tx_done_reg;
        tx_busy_next  = tx_busy_reg;
        data_cnt_next = data_cnt_reg;
        tick_cnt_next = tick_cnt_reg;
        tx_data_next  = tx_data_buf;

        case (state)
            IDLE: begin
                tx_next      = 1'b1;
                tx_done_next = 1'b0;
                tx_busy_next = 1'b0;
                if (start_trig) begin
                    state_next   = START;
                    tx_data_next = tx_data;
                    tx_busy_next = 1'b1;
                    tx_next      = 1'b0;
                end
            end
            START: begin
                if (b_16tick) begin
                    if (tick_cnt_reg == 15) begin
                        state_next    = DATA;
                        tick_cnt_next = '0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = tx_data_buf[0];
                if (b_16tick) begin
                    if (tick_cnt_reg == 15) begin
                        tick_cnt_next = '0;
                        if (data_cnt_reg == 7) begin
                            data_cnt_next = '0;
                            state_next    = STOP;
                            tx_next       = 1'b1;
                        end else begin
                            data_cnt_next = data_cnt_reg + 1;
                            tx_data_next  = tx_data_buf >> 1;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_16tick) begin
                    if (tick_cnt_reg == 15) begin
                        state_next    = IDLE;
                        tick_cnt_next = '0;
                        tx_done_next  = 1'b1;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule



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
