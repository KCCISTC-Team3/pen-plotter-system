`timescale 1ns / 1ps

module UART_RX #(
    parameter DATA_WIDTH = 8
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  rx,
    input  logic                  b_16tick,
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                  rx_done,
    output logic                  rx_busy
);
    localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    
    logic [1:0] state, state_next;

    logic       rx_done_reg, rx_done_next;
    logic       rx_busy_reg, rx_busy_next;

    logic [4:0] tick_cnt_reg, tick_cnt_next;
    logic [2:0] data_cnt_reg, data_cnt_next;

    logic [DATA_WIDTH-1:0] rx_data_buf, rx_data_next;

    assign rx_data = rx_data_buf;
    assign rx_done = rx_done_reg;
    assign rx_busy = rx_busy_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            state        <= IDLE;
            rx_done_reg  <= 1'b0;
            rx_busy_reg  <= 1'b0;
            data_cnt_reg <= '0;
            tick_cnt_reg <= '0;
            rx_data_buf  <= '0;
        end else begin
            state        <= state_next;
            rx_done_reg  <= rx_done_next;
            rx_busy_reg  <= rx_busy_next;
            data_cnt_reg <= data_cnt_next;
            tick_cnt_reg <= tick_cnt_next;
            rx_data_buf  <= rx_data_next;
        end
    end

    always_comb begin
        state_next     = state;
        rx_done_next   = rx_done_reg;
        rx_busy_next   = rx_busy_reg;
        data_cnt_next  = data_cnt_reg;
        tick_cnt_next  = tick_cnt_reg;
        rx_data_next   = rx_data_buf;
        case (state)
            IDLE: begin
                rx_busy_next = 1'b0;
                rx_done_next = 1'b0;
                if (rx == 0) begin
                    state_next   = START;
                    rx_busy_next = 1'b1;
                end
            end
            START: begin
                if (b_16tick) begin
                    if (tick_cnt_reg == 23) begin
                        tick_cnt_next = '0;
                        state_next    = DATA;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_16tick) begin
                    if (tick_cnt_reg == 0) begin
                        rx_data_next[7] = rx;
                    end
                    if (tick_cnt_reg == 15) begin
                        tick_cnt_next = '0;
                        if (data_cnt_reg == 7) begin
                            data_cnt_next = '0;
                            state_next    = STOP;
                        end else begin
                            data_cnt_next = data_cnt_reg + 1;
                            rx_data_next  = rx_data_buf >> 1;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_16tick) begin
                    state_next   = IDLE;
                    rx_done_next = 1'b1;
                end
            end
        endcase
    end
endmodule