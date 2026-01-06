`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 09:28:39
// Design Name: 
// Module Name: uart_rx_fifo
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


module uart_rx_fifo(
    input clk,
    input reset,
    input rx,
    output empty,
    output [7:0]pop_data,
    output rx_done
    );
    
    wire w_b_tick;
    wire [7:0] w_rx_data;
    wire w_rx_done;
    assign rx_done = w_rx_done;
    
    
    tick_gen_16 U_BOARD_TICK_GEN (
    .clk(clk),
    .rst(reset),
    .b_16tick(w_b_tick)
    );
    
     uart_rx U_UART_RX(
    .clk(clk),
    .rst(reset),
    .b_16tick(w_b_tick),
    .rx(rx),
    .rx_data(w_rx_data),
    .rx_done(w_rx_done),
    .rx_busy()
    );
    
    fifo U_RX_FIFO(
    .clk(clk),
    .rst(reset),
    .push_data(w_rx_data),
    .push(w_rx_done),
    .pop(~empty), 
    .pop_data(pop_data), // to kit and tx
    .full(),
    .empty(empty) // to kit and tx
    );
endmodule



