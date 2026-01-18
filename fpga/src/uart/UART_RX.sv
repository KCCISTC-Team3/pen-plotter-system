`timescale 1ns / 1ps

module UART_RX #(
    parameter DATA_WIDTH = 8,
    parameter SAMPLING   = 16
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  b_tick,
    input  logic                  rx,
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                  rx_done
);

    typedef enum {
        IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } state_e;

    state_e state, state_next;

    logic [$clog2(SAMPLING)-1:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [$clog2(DATA_WIDTH)-1:0] bit_cnt_reg, bit_cnt_next;
    logic [DATA_WIDTH-1:0] rx_data_reg, rx_data_next;
    logic rx_done_reg, rx_done_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state          <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            rx_data_reg    <= 0;
            rx_done_reg    <= 1'b0;
        end else begin
            state          <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            rx_data_reg    <= rx_data_next;
            rx_done_reg    <= rx_done_next;
        end
    end

    always_comb begin
        state_next      = state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        rx_data_next    = rx_data_reg;
        rx_done_next    = 1'b0;
        case (state)
            IDLE: begin
                if (!rx) begin
                    state_next = RX_START;
                    b_tick_cnt_next = 0;
                end
            end
            RX_START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == (SAMPLING >> 1) - 1) begin
                        b_tick_cnt_next = 0;
                        state_next      = RX_DATA;
                    end else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
            RX_DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == SAMPLING - 1) begin
                        b_tick_cnt_next = 0;
                        rx_data_next    = {rx, rx_data_reg[DATA_WIDTH-1:1]};
                        if (bit_cnt_reg == DATA_WIDTH - 1) begin
                            bit_cnt_next = 0;
                            state_next   = RX_STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
            RX_STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == SAMPLING - 1) begin
                        b_tick_cnt_next = 0;
                        rx_done_next = 1'b1;
                        state_next = IDLE;
                    end else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
        endcase
    end

endmodule
