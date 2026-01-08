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

module rx_ram (
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

module tx_ram (
    input  logic        clk,
    input  logic        reset,
    input  logic        we, //canny_en
    input  logic [7:0]  wData, //canny_data[0]
    input  logic [$clog2(30*170)-1:0] wAddr, //addr_cnt
    input  logic frame_tick,   // tick signal
    input  logic         re,
    output logic [7:0]   rData, 
    output logic frame_done   // hold signal 

);
    logic [7:0] mem [0:(30*170 )-1];

    //read address count
    logic [$clog2(30*170)-1:0] rAddr_cnt;

    always_ff @(posedge clk) begin
        if (we) mem[wAddr] <= wData;
    end

    assign rData = mem[rAddr_cnt];
    
    always_ff @(posedge clk) begin
        if(reset) begin
            rAddr_cnt <= 0;
        end 
        else begin
            if (re) begin
                if(rAddr_cnt == (30*170)) begin
                    rAddr_cnt <= 0;
                end
                else begin
                    rAddr_cnt <= rAddr_cnt + 1;
                end
            end 
            else begin
                rAddr_cnt <= rAddr_cnt;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            frame_done <= 0;
        end 
        else begin
            if(frame_tick) begin
                frame_done <= 1;
            end
            else if (rAddr_cnt == (30*170)) begin
                frame_done <= 0;
            end
            else begin
                frame_done <= frame_done;
            end
        end
    end

endmodule