`timescale 1ns / 1ps

module Grayscale #(
    parameter WIDTH = 8,
    parameter BRIGHTNESS_ADD = 30,
    parameter BRIGHTNESS_SUB = 30
) (
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
    output logic [WIDTH-1:0] o_data
);

    logic        [WIDTH+7:0] r_sum, g_sum, b_sum;
    logic        [WIDTH+7:0] gray_sum;
    logic signed [WIDTH+8:0] gray_bright;

    logic [2:0] v_delay, h_delay, d_delay;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            v_delay     <= '0;
            h_delay     <= '0;
            d_delay     <= '0;
            r_sum       <= '0;
            g_sum       <= '0;
            b_sum       <= '0;
            gray_sum    <= '0;
            gray_bright <= '0;
            o_data      <= '0;
            o_vsync     <= '0;
            o_hsync     <= '0;
            o_de        <= '0;
        end else begin
            v_delay <= {v_delay[1:0], i_vsync};
            h_delay <= {h_delay[1:0], i_hsync};
            d_delay <= {d_delay[1:0], i_de};

            r_sum <= (i_r_data << 6) + (i_r_data << 3) + (i_r_data << 2) + i_r_data;          // 64 +8 +4 +1   == 77
            g_sum <= (i_g_data << 7) + (i_g_data << 4) + (i_g_data << 2) + (i_g_data << 1);   // 128 +16 +4 +2 == 150
            b_sum <= (i_b_data << 4) + (i_b_data << 3) + (i_b_data << 2) + i_b_data;          // 16 +8 +4 +1   == 29

            gray_sum <= (r_sum + g_sum + b_sum) >> 8;

            if (d_delay[1]) begin
                gray_bright <= $signed({1'b0, gray_sum}) + BRIGHTNESS_ADD -
                    BRIGHTNESS_SUB;
            end

            if (gray_bright > 255) begin
                o_data <= 8'hFF;
            end else if (gray_bright < 0) begin
                o_data <= 8'h00;
            end else begin
                o_data <= gray_bright[7:0];
            end

            o_vsync <= v_delay[2];
            o_hsync <= h_delay[2];
            o_de    <= d_delay[2];
        end
    end

endmodule
