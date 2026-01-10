`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 09:23:52
// Design Name: 
// Module Name: uart_tx
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


module uart_tx(
    input clk,
    input rst,
    input start_trig,
    input [7:0]tx_data,
    input b_16tick,
    output tx,
    output tx_busy,
    output tx_done 
    );



    parameter IDLE =2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;

    reg [1:0] current_state, next_state;

    reg tx_r, tx_n;
    reg tx_done_r, tx_done_n;
    reg tx_busy_r, tx_busy_n;

    reg [3:0] b_16tick_cnt_r, b_16tick_cnt_n; //max 23
    reg [2:0] data_cnt_r, data_cnt_n; //max 7

    reg [7:0]tx_data_buf, tx_data_n;

    //output
    assign tx= tx_r;
    assign tx_busy = tx_busy_r;
    assign tx_done = tx_done_r;







    always @(posedge clk) begin
        if(rst) begin
            current_state <= IDLE;
            tx_r          <= 0;
            tx_done_r     <= 0;
            tx_busy_r     <= 0;
            data_cnt_r    <= 0;
            b_16tick_cnt_r <= 0;
            tx_data_buf    <= 0;
 

        end else begin
            current_state <= next_state;
            tx_r          <= tx_n;
            tx_done_r     <= tx_done_n;
            tx_busy_r     <= tx_busy_n;
            data_cnt_r    <= data_cnt_n;
            b_16tick_cnt_r <= b_16tick_cnt_n;
            tx_data_buf    <= tx_data_n;
        end
    end




    always @(*) begin
        next_state = current_state;
        tx_n       = tx_r;
        tx_done_n  = tx_done_r;
        tx_busy_n  = tx_busy_r;
        data_cnt_n = data_cnt_r;
        b_16tick_cnt_n = b_16tick_cnt_r;
        tx_data_n      = tx_data_buf;


        case (current_state)
        IDLE   : begin
            tx_n = 1;
            tx_busy_n =0;
            tx_done_n =0;

            if(start_trig)begin
                next_state = START;
                tx_data_n = tx_data;
                tx_busy_n =1;
                tx_n=0;
            end
        end
        START   : begin
            
            if(b_16tick) begin
                if(b_16tick_cnt_r ==15) begin
                    next_state = DATA;
                    b_16tick_cnt_n = 0;
                end else begin
                    b_16tick_cnt_n = b_16tick_cnt_r +1;
                end
            end
            
        end


        DATA    : begin
            tx_n = tx_data_buf[0];
            
            if(b_16tick) begin
                
                if(b_16tick_cnt_r==15)begin
                    b_16tick_cnt_n =0;
                    if(data_cnt_r==7 )begin
                        data_cnt_n =0;
                        next_state = STOP;
                        tx_n = 1;
                    end else begin
                        data_cnt_n = data_cnt_r +1;
                        tx_data_n = tx_data_buf >> 1;
                    end
                end else begin
                    b_16tick_cnt_n = b_16tick_cnt_n +1 ;
                end
            end
        end
        STOP    : begin
            if (b_16tick) begin
                if(b_16tick_cnt_r==15) begin
                    next_state = IDLE; 
                    b_16tick_cnt_n = 0;
                    tx_done_n =1;
                    tx_busy_n =0;
                end else begin
                    b_16tick_cnt_n = b_16tick_cnt_n +1 ;
                end
            end
            
        end
        endcase
    end


    
endmodule