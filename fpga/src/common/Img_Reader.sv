`timescale 1ns / 1ps

module Img_Reader #(
    parameter RGB_WIDTH  = 24,
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 80,    //176
    parameter IMG_HEIGHT = 120,   //240
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  start_read,
    input  logic [ RGB_WIDTH-1:0] img,
    output logic [ADDR_WIDTH-1:0] addr,
    output logic                  o_de,
    output logic                  re,
    output logic [DATA_WIDTH-1:0] r_port,
    output logic [DATA_WIDTH-1:0] g_port,
    output logic [DATA_WIDTH-1:0] b_port
);
    logic [ $clog2(IMG_WIDTH)-1:0] x_cnt;
    logic [$clog2(IMG_HEIGHT)-1:0] y_cnt;
    logic                          reading;
    logic [         RGB_WIDTH-1:0] reg_rgb_data;

    always_ff @(posedge clk) begin
        if (reset) begin
            reading <= 1'b0;
        end else if (start_read) begin
            reading <= 1'b1;
        end else if (x_cnt == (IMG_WIDTH - 1) && y_cnt == (IMG_HEIGHT - 1)) begin
            reading <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset || !reading) begin
            x_cnt <= '0;
            y_cnt <= '0;
        end else begin
            if (x_cnt == (IMG_WIDTH - 1)) begin
                x_cnt <= '0;
                if (y_cnt == (IMG_HEIGHT - 1)) y_cnt <= '0;
                else y_cnt <= y_cnt + 1;
            end else begin
                x_cnt <= x_cnt + 1;
            end
        end
    end

    assign addr = reading ? (y_cnt * IMG_WIDTH + x_cnt) : '0;

    always_ff @(posedge clk) begin
        re   <= reading;
        o_de <= re;
    end

    assign reg_rgb_data = re ? img : '0;
    assign {r_port, g_port, b_port} = o_de ? reg_rgb_data : '0;

endmodule
