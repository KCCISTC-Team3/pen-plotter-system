`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/13 04:10:44
// Design Name: 
// Module Name: Cam_TX_TOP
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


module Cam_TX_TOP #(
    parameter DATA_WIDTH  = 8,
    parameter TOTAL_BYTES = 176*240,
    parameter ADDR_WIDTH  = $clog2(TOTAL_BYTES),
    parameter FIFO_DEPTH  = 2
) (
    input logic clk,
    input logic reset,
    input logic start_btn, // from btn_debonce
    input logic [DATA_WIDTH*3-1:0] rData, // from frame buf
    output logic [ADDR_WIDTH-1:0] rAddr, // to frame buf
    output logic oe, // to frame buf
    output tx // to img process fpga
    );

    logic tx_fifo_full;
    logic [DATA_WIDTH-1:0] push_data;
    logic push_en;


    uart_tx_fsm #(
    .DATA_WIDTH (DATA_WIDTH),
    .TOTAL_BYTES(TOTAL_BYTES),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) u_fsm (
    .clk         (clk),
    .reset       (reset),
    .start_btn   (start_btn),
    .rData       (rData),
    .tx_fifo_full(tx_fifo_full),
    .push_data   (push_data),
    .rAddr       (rAddr),
    .oe          (oe),
    .push_en(push_en),
    .one_pixel_done()
  );


  UART_TX_FIFO #(
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH)
  ) u_uart_fifo (
    .clk         (clk),
    .reset       (reset),
    .tx_data     (push_data),
    .push        (push_en && ~tx_fifo_full), 
    .tx          (tx),
    .tx_fifo_full(tx_fifo_full)
  );


endmodule
