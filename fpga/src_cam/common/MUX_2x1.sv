`timescale 1ns / 1ps

module MUX_2x1 #(
    parameter RGB_WIDTH = 24
) (
    input  logic [RGB_WIDTH-1:0] i_cam_rgb,
    input  logic [RGB_WIDTH-1:0] i_pc_rgb,
    input  logic                 sel,
    output logic [RGB_WIDTH-1:0] o_rgb_wData
);
    assign o_rgb_wData = sel ? i_pc_rgb : i_cam_rgb;
    
endmodule