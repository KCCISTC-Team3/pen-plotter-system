`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 20:36:44
// Design Name: 
// Module Name: img_ram
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

module img_ram (
    input  logic        clk,
    input  logic        we, //pixel_done
    input  logic [23:0] wData, 
    input  logic [$clog2(240*170)-1:0] wAddr, //pixel_cnt
    input  logic frame_done,
    output logic o_frame_done,

    input  logic         oe,
    input  logic [$clog2(240*170)-1:0] rAddr, 
    output logic [23:0] imgData  
);

    logic [23:0] mem [0:(240*170)-1];

    always_ff @(posedge clk) begin
        o_frame_done <= frame_done;
    end

    always_ff @(posedge clk) begin
        if (we) mem[wAddr] <= wData;
    end

    always_ff @(posedge clk) begin
        if (oe) imgData <= mem[rAddr];
    end

endmodule