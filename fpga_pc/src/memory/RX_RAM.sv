`timescale 1ns / 1ps

module RX_RAM #(
    parameter RGB_WIDTH    = 24,
    parameter IMG_WIDTH    = 80,  //176
    parameter IMG_HEIGHT   = 120,  //240
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT,
    parameter ADDR_WIDTH   = $clog2(TOTAL_PIXELS)
) (
    input  logic                  clk,
    input  logic                  we,
    input  logic [ RGB_WIDTH-1:0] wData,
    input  logic [ADDR_WIDTH-1:0] wAddr,
    input  logic                  frame_done,
    output logic                  o_frame_done,
    input  logic                  oe,
    input  logic [ADDR_WIDTH-1:0] rAddr,
    output logic [ RGB_WIDTH-1:0] imgData
);
    logic [RGB_WIDTH-1:0] mem[0:TOTAL_PIXELS-1];

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