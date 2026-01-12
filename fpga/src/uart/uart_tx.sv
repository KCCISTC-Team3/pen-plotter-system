`timescale 1ns / 1ps

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
                tx_busy_next = 1'b0;
                tx_done_next = 1'b0;
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
