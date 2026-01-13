`timescale 1ns / 1ps

module FIFO  #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
)(
    input        clk,
    input        reset,
    input  [DATA_WIDTH-1:0] push_data,
    input        push,
    input        pop,
    output [DATA_WIDTH-1:0] pop_data,
    output       full,
    output       empty
);

    wire [ADDR_WIDTH-1:0] w_wptr, w_rptr;

    register_file  #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_REG_FILE (
        .clk(clk),
        .wptr(w_wptr),
        .rptr(w_rptr),
        .push_data(push_data),
        .wr(~full & push),
        .pop_data(pop_data)
    );

    fifo_cu #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_FIFO_CU (
        .clk  (clk),
        .rst  (reset),
        .push (push),
        .pop  (pop),
        .wptr (w_wptr),
        .rptr (w_rptr),
        .full (full),
        .empty(empty)
    );

endmodule

module register_file#(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 5
)  (
    input        clk,
    input  [ADDR_WIDTH-1:0] wptr,
    input  [ADDR_WIDTH-1:0] rptr,
    input  [DATA_WIDTH-1:0] push_data,
    input        wr,
    output [DATA_WIDTH-1:0] pop_data
);
    localparam DEPTH = 2 ** ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] ram[0:DEPTH-1];

    // output CL
    assign pop_data = ram[rptr];

    always @(posedge clk) begin
        if (wr) begin
            ram[wptr] <= push_data;
        end
    end

endmodule

module fifo_cu #(
    parameter ADDR_WIDTH = 3
)(
    input        clk,
    input        rst,
    input        push,
    input        pop,
    output [ADDR_WIDTH-1:0] wptr,
    output [ADDR_WIDTH-1:0] rptr,
    output       full,
    output       empty
);

    // output
    reg [ADDR_WIDTH-1:0] wptr_reg, wptr_next;
    reg [ADDR_WIDTH-1:0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 0;
            empty_reg <= 1'b1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            push, pop
        })
            2'b01: begin  // pop
          
                if (!empty_reg) begin
                    full_next = 0;
                    rptr_next = rptr_reg + 1;
                    if (wptr_reg == rptr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b10: begin  // push
          
                if (!full_reg) begin
                    empty_next = 0;
                    wptr_next = wptr_reg + 1;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b11: begin
                if (empty_reg == 1'b1) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else if (full_reg == 1'b1) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else begin
                    // not be full, empty
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end

endmodule


/*
module FIFO #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic [DATA_WIDTH-1:0] push_data,
    input  logic                  push,
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
        .reset    (reset),
        .wptr     (wptr),
        .rptr     (rptr),
        .push_data(push_data),
        .wr       (push_en),
        .pop_en   (pop_en),
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
    input  logic                  reset,
    input  logic [ADDR_WIDTH-1:0] wptr,
    input  logic [ADDR_WIDTH-1:0] rptr,
    input  logic [DATA_WIDTH-1:0] push_data,
    input  logic                  wr,
    input  logic                  pop_en,
    output logic [DATA_WIDTH-1:0] pop_data
);
    localparam DEPTH = 2 ** ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] ram[0:DEPTH-1];
    logic [DATA_WIDTH-1:0] pop_data_reg;

    assign pop_data = pop_data_reg;

    always_ff @(posedge clk) begin
        if (wr) begin
            ram[wptr] <= push_data;
        end
        if (pop_en) begin
            pop_data_reg <= ram[rptr];
        end
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

    always_ff @(posedge clk) begin
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
                rptr_next = rptr_reg + 1;
                full_next = 1'b0;
                if (wptr_reg == (rptr_reg + 1)) empty_next = 1'b1;
            end
            2'b10: begin  // PUSH only
                wptr_next  = wptr_reg + 1;
                empty_next = 1'b0;
                if ((wptr_reg + 1) == rptr_reg) full_next = 1'b1;
            end
            2'b11: begin  // PUSH + POP
                wptr_next  = wptr_reg + 1;
                rptr_next  = rptr_reg + 1;
                full_next  = 1'b0;
                empty_next = 1'b0;
            end
        endcase
    end

endmodule

*/