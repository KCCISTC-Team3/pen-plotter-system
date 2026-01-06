`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 09:28:24
// Design Name: 
// Module Name: uart_tx_fifo
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


module uart_tx_fifo(
    input clk,
    input reset,
    input [7:0]tx_data,
    input push,
    output tx,
    outpuy tx_fifo_full
    );
    
    wire [7:0] w_tx_data;
    wire w_tx_empty, w_tx_busy;
    wire tx_start_pulse = (~w_tx_empty) & (~w_tx_busy); 
    wire tx_pop_pulse   = tx_start_pulse;
    
     tick_gen_16 U_BOARD_TICK_GEN (
    .clk(clk),
    .rst(reset),
    .b_16tick(w_b_tick)
    );

    uart_tx U_UART_TX(
    .clk(clk),
    .rst(reset),
    .b_16tick(w_b_tick),
    .start_trig(tx_start_pulse),
    .tx_data(w_tx_data),
    .tx(tx),
    .tx_busy(w_tx_busy),
    .tx_done(w_tx_done)
    );

    fifo U_TX_FIFO(
    .clk(clk),
    .rst(reset),
    .push_data(tx_data),
    .push(push), 
    .pop(tx_pop_pulse),
    .pop_data(w_tx_data), // to tx-> pc
    .full(tx_fifo_full), // to kit
    .empty(w_tx_empty)
    );
    
    
endmodule
