`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 09:24:19
// Design Name: 
// Module Name: uart_rx
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


module uart_rx(
    input clk,
    input rst,
    input rx,
    input b_16tick,
    output[7:0]rx_data,
    output rx_done,
    output rx_busy
    );


    // tick_gen_16 U_GEN_16_TICK (
    // .clk(clk),
    // .rst(rst),
    // .b_16tick(b_16tick)
    // );


    parameter IDLE =2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;
    reg [1:0] current_state, next_state;

    reg rx_done_r, rx_done_n;
    reg rx_busy_r, rx_busy_n;
    
    reg [4:0] b_16tick_cnt_r, b_16tick_cnt_n; //max 23
    reg [2:0] data_cnt_r, data_cnt_n; //max 7

    reg [7:0] rx_data_buf, rx_data_n;

    //output

    assign rx_data = rx_data_buf;
    assign rx_done = rx_done_r;
    assign rx_busy = rx_busy_r;


    always @(posedge clk) begin
        if(rst)begin
            current_state <= IDLE;
            rx_done_r     <= 0;
            rx_busy_r     <= 0;
            data_cnt_r    <= 0;
            b_16tick_cnt_r <= 0;
            rx_data_buf    <= 0;
        end else begin
            current_state <= next_state;
            rx_done_r     <= rx_done_n;
            rx_busy_r     <= rx_busy_n;
            data_cnt_r    <= data_cnt_n;
            b_16tick_cnt_r <= b_16tick_cnt_n;
            rx_data_buf    <= rx_data_n;
        end
    end

    always @(*) begin
        next_state = current_state;
        rx_done_n  = rx_done_r;
        rx_busy_n  = rx_busy_r;
        data_cnt_n = data_cnt_r;
        b_16tick_cnt_n = b_16tick_cnt_r;
        rx_data_n      = rx_data_buf;


        case (current_state)
           IDLE : begin
            rx_busy_n = 1'b0; 
            rx_done_n =1'b0; 
                if(rx==0)begin
                    next_state = START;
                    rx_busy_n = 1'b1;
                    
                end
           end
           START : begin
                if(b_16tick)begin
                    if(b_16tick_cnt_r==23)begin
                        b_16tick_cnt_n =0;
                        next_state = DATA;
                    end else begin
                        b_16tick_cnt_n = b_16tick_cnt_r +1;
                    end
                end 
           end
           DATA : begin
                if(b_16tick)begin
                    
                    if(b_16tick_cnt_r==0)begin
                        rx_data_n[7] =rx;
                    end

                    if(b_16tick_cnt_r==15) begin
                        b_16tick_cnt_n =0;
                        if(data_cnt_r ==7) begin
                            data_cnt_n =0;
                            next_state = STOP;
                        end else begin
                            data_cnt_n = data_cnt_r +1;
                            rx_data_n = rx_data_buf >> 1;
                        end
                    end else begin
                        b_16tick_cnt_n = b_16tick_cnt_r +1;
                    end


                end 
           end
           STOP : begin            
                if(b_16tick) begin
                    next_state =IDLE; 
                    rx_done_n =1;
                end

           end
        endcase
    end
endmodule

