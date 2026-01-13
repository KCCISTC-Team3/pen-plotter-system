`timescale 1ns / 1ps

module Frame_Buffer #(
    parameter RGB_WIDTH    = 24,
    parameter IMG_WIDTH    = 176,
    parameter IMG_HEIGHT   = 240,
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT,
    parameter ADDR_WIDTH   = $clog2(TOTAL_PIXELS)
) (
    // write side
    input  logic                  wclk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] wAddr,
    input  logic  [ 15:0]  wData,
    // read side
    input  logic                  rclk,
    input  logic                  oe,
    input  logic [ADDR_WIDTH-1:0] rAddr,
    output logic  [ 15:0]  rData
);
    logic  [ 15:0]  mem[0:TOTAL_PIXELS-1];

    // write side
    always_ff @(posedge wclk) begin
        if (we) mem[wAddr] <= wData;
    end

    // read side port A
    always_ff @(posedge rclk) begin
        if (oe) rData <= mem[rAddr];
    end
endmodule