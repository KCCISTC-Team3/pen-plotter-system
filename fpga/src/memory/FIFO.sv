`timescale 1ns / 1ps

module FIFO #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 5
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  push,
    input  logic [DATA_WIDTH-1:0] push_data,
    input  logic                  pop,
    output logic [DATA_WIDTH-1:0] pop_data,
    output logic                  full,
    output logic                  empty
);
    localparam DEPTH = 2 ** ADDR_WIDTH;

    logic [ADDR_WIDTH-1:0] wptr, rptr;
    logic push_en, pop_en;

    assign push_en = push & ~full;
    assign pop_en  = pop & ~empty;

    Register_File #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_Register_File (
        .clk      (clk),
        .wr       (push_en),
        .wptr     (wptr),
        .rptr     (rptr),
        .push_data(push_data),
        .pop_data (pop_data)
    );

    FIFO_Control_Unit #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_FIFO_Control_Unit (
        .clk    (clk),
        .reset  (reset),
        .push_en(push_en),
        .pop_en (pop_en),
        .wptr   (wptr),
        .rptr   (rptr),
        .full   (full),
        .empty  (empty)
    );

endmodule

module Register_File #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 5
) (
    input  logic                  clk,
    input  logic                  wr,
    input  logic [ADDR_WIDTH-1:0] wptr,
    input  logic [ADDR_WIDTH-1:0] rptr,
    input  logic [DATA_WIDTH-1:0] push_data,
    output logic [DATA_WIDTH-1:0] pop_data
);
    localparam DEPTH = 2 ** ADDR_WIDTH;

    (* ram_style = "distributed" *) logic [DATA_WIDTH-1:0] ram[0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (wr) begin
            ram[wptr] <= push_data;
        end
    end

    always_ff @(posedge clk) begin
        pop_data <= ram[rptr];
    end


endmodule

module FIFO_Control_Unit #(
    parameter ADDR_WIDTH = 5
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  push_en,
    input  logic                  pop_en,
    output logic [ADDR_WIDTH-1:0] wptr,
    output logic [ADDR_WIDTH-1:0] rptr,
    output logic                  full,
    output logic                  empty
);
    logic [ADDR_WIDTH-1:0] wptr_reg, wptr_next;
    logic [ADDR_WIDTH-1:0] rptr_reg, rptr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            wptr_reg  <= '0;
            rptr_reg  <= '0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always_comb begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({
            push_en, pop_en
        })
            2'b01: begin  // POP only
                full_next = 1'b0;
                if (!empty_reg) begin
                    rptr_next = rptr_reg + 1;
                    if (wptr_reg == rptr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b10: begin  // PUSH only
                empty_next = 1'b0;
                if (!full_reg) begin
                    wptr_next = wptr_reg + 1;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b11: begin  // PUSH + POP
                if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else if (full_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end

endmodule
