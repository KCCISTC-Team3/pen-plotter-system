`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 11:00:04
// Design Name: 
// Module Name: tick_gen_16
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


module tick_gen_16(
    input  clk,
    input  rst,
    output b_16tick
    );

    parameter BAUDRATE = 115200*16 ;
    localparam BAUD_COUNT = 100_000_000/BAUDRATE;
    reg [$clog2(BAUD_COUNT)-1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;

    //output

    assign b_16tick = tick_reg ;


    always @(posedge clk) begin
        if(rst) begin
            count_reg <= 0;
            tick_reg <=0;
        end
        else begin
            count_reg <= count_next;
            tick_reg <= tick_next;
        end
    end

    always @(*) begin
        count_next = count_reg;
        tick_next = 1'b0;

        if(count_reg == BAUD_COUNT-1) begin
            count_next = 0;
            tick_next  =1'b1;
        end
        else begin
            count_next = count_reg +1;
            tick_next  =1'b0;
        end
     end

endmodule
