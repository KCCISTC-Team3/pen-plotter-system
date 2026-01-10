 `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 11:34:48
// Design Name: 
// Module Name: data_assembly_fsm
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


module data_assembly_fsm(
    input        clk,
    input        reset,
    input        empty,
    input  [7:0]  pop_data,
    input         cam_mode, // 1: camera mode, 0: uart mode
    output [23:0] rgb_data,
    output  reg   pixel_done, // we
    output  reg [15:0] pixel_cnt, // addr 0 ~ 40799
    output  reg     frame_done
    );
    
     
 typedef enum logic [3:0] {
        ST_IDLE,
        ST_START_CHECK,
        ST_START,
        ST_R,
        ST_G,
        ST_B,
        ST_ASSEMBLE,
        ST_CAM_MODE
    } state;

    state current_state, next_state;

    reg [7:0] reg_r, reg_g, reg_b;
    reg [7:0] reg_r_next, reg_g_next, reg_b_next;
    reg [7:0] reg_r_temp, reg_g_temp, reg_b_temp;
    reg [15:0] pixel_cnt_next;

    assign rgb_data = {reg_r, reg_g, reg_b};


    always @(posedge clk) begin
        if(reset) begin
            current_state <= ST_IDLE;
            reg_r <= 8'h00;
            reg_g <= 8'h00; 
            reg_b <= 8'h00;
            pixel_cnt <= 16'h0000;
        end else begin
            current_state <= next_state;
            reg_r <= reg_r_next;
            reg_g <= reg_g_next;
            reg_b <= reg_b_next;
            pixel_cnt <= pixel_cnt_next;
        end
    end



    always @(*) begin
        next_state = current_state; // default stay
        reg_r_next = reg_r;
        reg_g_next = reg_g;
        reg_b_next = reg_b;
        pixel_done = 1'b0;
        frame_done = 1'b0;
        pixel_cnt_next = pixel_cnt;

        case (current_state)
            ST_IDLE: begin
                if(~empty)
                    next_state = ST_START_CHECK;
                else
                    next_state = ST_IDLE;
            end
            ST_START_CHECK: begin
                if(pop_data == 8'hAA)
                 if(cam_mode)
                    next_state = ST_CAM_MODE;
                else
                    next_state = ST_START;
                else
                next_state = ST_IDLE;

            end
            ST_START: begin
                if(~empty) next_state = ST_R;
            end
            ST_R: begin
                reg_r_next = pop_data;
                if(~empty) next_state = ST_G;
            end
            ST_G: begin
                reg_g_next = pop_data;
                if(~empty) next_state = ST_B;
            end
            ST_B: begin
                reg_b_next = pop_data;
                next_state = ST_ASSEMBLE;
            end
            ST_ASSEMBLE: begin
                if(~empty & (pixel_cnt < (176*240 - 1)))begin
                    pixel_done = 1'b1;
                    next_state = ST_R;
                    pixel_cnt_next = pixel_cnt + 1;
                end else if((pixel_cnt == (176*240 - 1))) begin
                    frame_done = 1'b1;
                    next_state = ST_IDLE;
                    pixel_cnt_next = 16'd0; 
                end
            end
            ST_CAM_MODE : begin
               frame_done = 1'b1;
                next_state = ST_IDLE;
                pixel_cnt_next = 16'd0; 
            end
        endcase
    end



endmodule

