`timescale 1ns / 1ps

module UART_TX_Controller #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  edge_tx_trig,
    input  logic                  tx_full,
    // Frame Buffer read interface
    output logic                  fb_re,
    output logic [ADDR_WIDTH-1:0] fb_rAddr,
    input  logic [           7:0] fb_rData,
    // FIFO write interface
    output logic                  wr_en,
    output logic [DATA_WIDTH-1:0] wr_data,
    // Status
    output logic                  sending,
    output logic                  frame_tx_done
);

    typedef enum {
        IDLE,
        READ_REQ,
        READ_WAIT,
        SEND,
        DONE
    } state_e;

    state_e state, state_next;

    logic [ADDR_WIDTH-1:0] pixel_cnt, pixel_cnt_next;
    logic [7:0] pixel_data, pixel_data_next;

    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    // =========================================================================
    // State Register
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            state      <= IDLE;
            pixel_cnt  <= '0;
            pixel_data <= '0;
        end else begin
            state      <= state_next;
            pixel_cnt  <= pixel_cnt_next;
            pixel_data <= pixel_data_next;
        end
    end

    // =========================================================================
    // FSM Logic
    // =========================================================================
    always_comb begin
        state_next      = state;
        pixel_cnt_next  = pixel_cnt;
        pixel_data_next = pixel_data;
        fb_re           = 1'b0;
        fb_rAddr        = '0;
        wr_en           = 1'b0;
        wr_data         = '0;
        sending         = 1'b0;

        case (state)
            IDLE: begin
                if (edge_tx_trig) begin
                    state_next     = READ_REQ;
                    pixel_cnt_next = '0;
                end
            end
            READ_REQ: begin
                sending    = 1'b1;
                fb_re      = 1'b1;
                fb_rAddr   = pixel_cnt;
                state_next = READ_WAIT;
            end
            READ_WAIT: begin
                sending         = 1'b1;
                pixel_data_next = fb_rData;
                state_next      = SEND;
            end
            SEND: begin
                sending = 1'b1;
                if (~tx_full) begin
                    wr_en   = 1'b1;
                    wr_data = pixel_data;

                    if (pixel_cnt == TOTAL_PIXELS - 1) begin
                        state_next     = DONE;
                        pixel_cnt_next = '0;
                    end else begin
                        pixel_cnt_next = pixel_cnt + 1;
                        state_next     = READ_REQ;
                    end
                end
            end
            DONE: begin
                state_next = IDLE;
            end
        endcase
    end

    // =========================================================================
    // Frame TX Done Signal
    // =========================================================================
    logic [3:0] done_pulse_cnt;

    always_ff @(posedge clk) begin
        if (reset) begin
            done_pulse_cnt <= '0;
        end else begin
            if (state == DONE) begin
                if (done_pulse_cnt < 10) done_pulse_cnt <= done_pulse_cnt + 1;
            end else begin
                done_pulse_cnt <= '0;
            end
        end
    end

    assign frame_tx_done = (done_pulse_cnt > 0 && done_pulse_cnt <= 5);

endmodule
