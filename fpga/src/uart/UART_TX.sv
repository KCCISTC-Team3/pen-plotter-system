`timescale 1ns / 1ps

module UART_TX #(
    parameter DATA_WIDTH = 8,
    parameter SAMPLING   = 16
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  b_tick,
    input  logic                  tx_start,
    input  logic [DATA_WIDTH-1:0] tx_data,
    output logic                  tx_busy,
    output logic                  tx
);

    typedef enum {
        IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } state_e;

    state_e state, state_next;

    logic [$clog2(SAMPLING)-1:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [$clog2(DATA_WIDTH)-1:0] bit_cnt_reg, bit_cnt_next;
    logic [DATA_WIDTH-1:0] data_buf_reg, data_buf_next;
    logic tx_reg, tx_next;
    logic tx_busy_reg, tx_busy_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state          <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            data_buf_reg   <= 0;
            tx_reg         <= 1'b1;
            tx_busy_reg    <= 1'b0;
        end else begin
            state          <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_buf_reg   <= data_buf_next;
            tx_reg         <= tx_next;
            tx_busy_reg    <= tx_busy_next;
        end
    end

    always_comb begin
        state_next      = state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        data_buf_next   = data_buf_reg;
        tx_next         = tx_reg;
        tx_busy_next    = tx_busy_reg;
        case (state)
            IDLE: begin
                tx_next      = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    b_tick_cnt_next = 0;
                    data_buf_next   = tx_data;
                    state_next      = TX_START;
                end
            end
            TX_START: begin
                tx_next      = 1'b0;
                tx_busy_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == SAMPLING - 1) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        state_next      = TX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == SAMPLING - 1) begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == DATA_WIDTH - 1) begin
                            state_next = TX_STOP;
                        end else begin
                            bit_cnt_next  = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == SAMPLING - 1) begin
                        b_tick_cnt_next = 0;
                        state_next      = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
