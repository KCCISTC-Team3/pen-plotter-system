`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 16:44:57
// Design Name: 
// Module Name: DS_Gray
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

module DS_Gray #(
    parameter WIDTH = 8,
    parameter BRIGHTNESS_ADD = 30,
    parameter BRIGHTNESS_SUB = 30
)(
    input  logic             clk,
    input  logic             rstn,
    input  logic             i_vsync,
    input  logic             i_hsync,
    input  logic             i_de,
    input  logic [WIDTH-1:0] i_r_data,
    input  logic [WIDTH-1:0] i_g_data,
    input  logic [WIDTH-1:0] i_b_data,
    output logic             o_vsync,
    output logic             o_hsync,
    output logic             o_de,
    output logic [WIDTH-1:0] o_r_data,
    output logic [WIDTH-1:0] o_g_data,
    output logic [WIDTH-1:0] o_b_data
);


    logic [WIDTH+9:0] gray_sum; 
    logic [WIDTH+9:0] gray_bright;
    
    // Sync Delay (1 Cycle)
    logic vsync_d, hsync_d, de_d;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            gray_sum    <= 0;
            gray_bright <= 0;
            o_r_data    <= 0;
            o_g_data    <= 0;
            o_b_data    <= 0;
            
            vsync_d <= 0; hsync_d <= 0; de_d <= 0;
            o_vsync <= 0; o_hsync <= 0; o_de <= 0;
        end else begin
            if (i_de) begin
                gray_sum <= (i_r_data * 77) + (i_g_data * 150) + (i_b_data * 29);
                gray_bright <= (gray_sum >> 8) + BRIGHTNESS_ADD - BRIGHTNESS_SUB;

                if (gray_bright > {WIDTH{1'b1}}) begin
                    o_r_data <= {WIDTH{1'b1}};
                    o_g_data <= {WIDTH{1'b1}};
                    o_b_data <= {WIDTH{1'b1}};
                end else begin
                    o_r_data <= gray_bright[WIDTH-1:0];
                    o_g_data <= gray_bright[WIDTH-1:0];
                    o_b_data <= gray_bright[WIDTH-1:0];
                end
            end else begin
                o_r_data <= 0;
                o_g_data <= 0;
                o_b_data <= 0;
            end

            o_vsync <= i_vsync;
            o_hsync <= i_hsync;
            o_de    <= i_de;
        end
    end

endmodule
