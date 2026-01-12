`timescale 1ns / 1ps

module TX_RAM #(
    parameter DATA_WIDTH  = 8,
    parameter TOTAL_PIXELS = 42240,
    parameter ADDR_WIDTH  = $clog2(TOTAL_PIXELS)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  we,
    input  logic [DATA_WIDTH-1:0] wData,
    input  logic [ADDR_WIDTH-1:0] wAddr,
    input  logic                  frame_tick,
    input  logic                  re,
    output logic [DATA_WIDTH-1:0] rData,
    output logic                  frame_done
);
    logic [DATA_WIDTH-1:0] mem[0:TOTAL_PIXELS-1];
    logic [ADDR_WIDTH-1:0] rAddr_cnt;

    always_ff @(posedge clk) begin
        rData <= mem[rAddr_cnt];
        if (we) mem[wAddr] <= wData;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            rAddr_cnt <= '0;
        end else begin
            if (re) begin
                if (rAddr_cnt == (TOTAL_PIXELS - 1)) begin
                    rAddr_cnt <= '0;
                end else begin
                    rAddr_cnt <= rAddr_cnt + 1;
                end
            end else if (~frame_done) begin
                rAddr_cnt <= '0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            frame_done <= 1'b0;
        end else begin
            if (frame_tick) begin
                frame_done <= 1'b1;
            end else if (rAddr_cnt == '0) begin
                frame_done <= 1'b0;
            end
        end
    end
endmodule
