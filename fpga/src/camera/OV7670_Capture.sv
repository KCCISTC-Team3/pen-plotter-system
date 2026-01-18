`timescale 1ns / 1ps

module OV7670_Capture #(
    parameter DATA_WIDTH   = 8,
    parameter RGB_WIDTH    = 16,
    parameter IMG_WIDTH    = 320,
    parameter IMG_HEIGHT   = 240,
    parameter CROP_WIDTH   = 176,
    parameter CROP_HEIGHT  = 240,
    parameter CROP_START_X = (IMG_WIDTH - CROP_WIDTH) >> 1,
    parameter CROP_START_Y = (IMG_HEIGHT - CROP_HEIGHT) >> 1,
    parameter ADDR_WIDTH   = $clog2(CROP_WIDTH * CROP_HEIGHT)
) (
    input  logic                  pclk,
    input  logic                  reset,
    // OV7670 side
    input  logic                  href,
    input  logic                  vsync,
    input  logic [DATA_WIDTH-1:0] data,
    // memory side
    output logic                  we,
    output logic [ADDR_WIDTH-1:0] wAddr,
    output logic [ RGB_WIDTH-1:0] wData
);
    logic [15:0] pixelData;
    logic        byte_toggle;
    logic [9:0] x_count, y_count;

    assign wData = pixelData;

    logic in_crop_region;
    assign in_crop_region = (x_count >= CROP_START_X) && 
                       (x_count < CROP_START_X + CROP_WIDTH) &&
                       (y_count >= CROP_START_Y) &&
                       (y_count < CROP_START_Y + CROP_HEIGHT);

    always_ff @(posedge pclk) begin
        if (reset) begin
            we          <= 0;
            wAddr       <= 0;
            pixelData   <= 0;
            byte_toggle <= 0;
            x_count     <= 0;
            y_count     <= 0;
        end else begin
            we <= 0;
            if (vsync) begin
                we          <= 0;
                wAddr       <= 0;
                byte_toggle <= 0;
                x_count     <= 0;
                y_count     <= 0;
            end else if (href) begin
                if (byte_toggle == 1'b0) begin
                    pixelData[15:8] <= data;
                    byte_toggle     <= 1'b1;
                end else begin
                    pixelData[7:0] <= data;
                    byte_toggle    <= 1'b0;
                    if (in_crop_region) begin
                        we <= 1'b1;
                        wAddr <= wAddr + 1;
                    end
                    if (x_count == IMG_WIDTH - 1) begin
                        x_count <= 0;
                        y_count <= y_count + 1;
                    end else begin
                        x_count <= x_count + 1;
                    end
                end
            end else begin
                x_count <= 0;
            end
        end
    end
endmodule
