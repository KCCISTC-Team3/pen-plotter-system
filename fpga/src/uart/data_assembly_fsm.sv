`timescale 1ns / 1ps

module Data_Assembly_FSM #(
    parameter DATA_WIDTH      = 8,
    parameter TOTAL_PIXELS    = 40800,
    parameter PIXEL_CNT_WIDTH = 16
) (
    input  logic                       clk,
    input  logic                       reset,
    input  logic                       empty,
    input  logic [     DATA_WIDTH-1:0] pop_data,
    input                              cam_mode, // 1: camera, 0: uart
    output logic [   3*DATA_WIDTH-1:0] rgb_data,
    output logic                       pixel_done,
    output logic [PIXEL_CNT_WIDTH-1:0] pixel_cnt,
    output logic                       frame_done
);
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_START_CHECK,
        ST_START,
        ST_R,
        ST_G,
        ST_B,
        ST_ASSEMBLE,
        ST_CAM_MODE
    } state_t;

    state_t state, state_next;

    logic [DATA_WIDTH-1:0] reg_r, reg_g, reg_b;
    logic [DATA_WIDTH-1:0] reg_r_next, reg_g_next, reg_b_next;
    logic [PIXEL_CNT_WIDTH-1:0] pixel_cnt_next;

    assign rgb_data = {reg_r, reg_g, reg_b};

    always_ff @(posedge clk) begin
        if (reset) begin
            state     <= ST_IDLE;
            reg_r     <= '0;
            reg_g     <= '0;
            reg_b     <= '0;
            pixel_cnt <= '0;
        end else begin
            state     <= state_next;
            reg_r     <= reg_r_next;
            reg_g     <= reg_g_next;
            reg_b     <= reg_b_next;
            pixel_cnt <= pixel_cnt_next;
        end
    end

    always_comb begin
        state_next     = state;
        reg_r_next     = reg_r;
        reg_g_next     = reg_g;
        reg_b_next     = reg_b;
        pixel_done     = 1'b0;
        frame_done     = 1'b0;
        pixel_cnt_next = pixel_cnt;

        case (state)
            ST_IDLE: begin
                if (~empty) state_next = ST_START_CHECK;
                else state_next = ST_IDLE;
            end
            ST_START_CHECK: begin
                if (pop_data == 8'hAA) begin
                    if (cam_mode) state_next = ST_CAM_MODE;
                    else state_next = ST_START;
                end else state_next = ST_IDLE;
            end
            ST_START: begin
                if (~empty) state_next = ST_R;
            end
            ST_R: begin
                reg_r_next = pop_data;
                if (~empty) state_next = ST_G;
            end
            ST_G: begin
                reg_g_next = pop_data;
                if (~empty) state_next = ST_B;
            end
            ST_B: begin
                reg_b_next = pop_data;
                state_next = ST_ASSEMBLE;
            end
            ST_ASSEMBLE: begin
                if (~empty & (pixel_cnt < (TOTAL_PIXELS - 1))) begin
                    pixel_done     = 1'b1;
                    state_next     = ST_R;
                    pixel_cnt_next = pixel_cnt + 1;
                end else if (pixel_cnt == (TOTAL_PIXELS - 1)) begin
                    frame_done     = 1'b1;
                    state_next     = ST_IDLE;
                    pixel_cnt_next = '0;
                end
            end
            ST_CAM_MODE: begin
                frame_done     = 1'b1;
                state_next     = ST_IDLE;
                pixel_cnt_next = 16'd0;
            end
        endcase
    end
endmodule
