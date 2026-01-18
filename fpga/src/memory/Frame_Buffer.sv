`timescale 1ns / 1ps

module Frame_Buffer #(
    parameter RGB_WIDTH    = 24,
    parameter IMG_WIDTH    = 176,
    parameter IMG_HEIGHT   = 240,
    parameter TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT,
    parameter ADDR_WIDTH   = $clog2(TOTAL_PIXELS)
) (
    // Write port
    input  logic                  wclk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] wAddr,
    input  logic [RGB_WIDTH-1:0]  wData,
    // Read port A
    input  logic                  rclk_a,
    input  logic                  oe_a,
    input  logic [ADDR_WIDTH-1:0] rAddr_a,
    output logic [RGB_WIDTH-1:0]  rData_a,
    // Read port B
    input  logic                  rclk_b,
    input  logic                  oe_b,
    input  logic [ADDR_WIDTH-1:0] rAddr_b,
    output logic [RGB_WIDTH-1:0]  rData_b
);

    logic [RGB_WIDTH-1:0] mem[0:TOTAL_PIXELS-1];

    // Write
    always_ff @(posedge wclk) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end

    // Read port A
    always_ff @(posedge rclk_a) begin
        if (oe_a) begin
            rData_a <= mem[rAddr_a];
        end
    end

    // Read port B
    always_ff @(posedge rclk_b) begin
        if (oe_b) begin
            rData_b <= mem[rAddr_b];
        end
    end

endmodule