`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 09:24:37
// Design Name: 
// Module Name: fifo
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


module fifo (
    input        clk,
    input        rst,
    input  [7:0] push_data,
    input        push,
    input        pop,
    output [7:0] pop_data,
    output       full,
    output       empty
);

    wire [4:0] w_wptr, w_rptr;

    wire push_en = push & ~full;
    wire pop_en  = pop  & ~empty;

    register_file U_REG_FILE (
        .clk      (clk),
        .rst      (rst),
        .wptr     (w_wptr),
        .rptr     (w_rptr),
        .push_data(push_data),
        .wr       (push_en),
        .pop_en   (pop_en),
        .pop_data (pop_data)
    );

    fifo_cu U_FIFO_CU (
        .clk     (clk),
        .rst     (rst),
        .push_en (push_en),   
        .pop_en  (pop_en),   
        .wptr    (w_wptr),
        .rptr    (w_rptr),
        .full    (full),
        .empty   (empty)
    );

endmodule



module register_file (
    input        clk,
    input        rst,
    input  [4:0] wptr,
    input  [4:0] rptr,
    input  [7:0] push_data,
    input        wr,
    input        pop_en,        // ? pop && !empty
    output [7:0] pop_data
);

    reg [7:0] ram[0:31];
    reg [7:0] pop_data_reg;

    assign pop_data = pop_data_reg;

    always @(posedge clk) begin
        if (wr) begin
            ram[wptr] <= push_data;
        end

        if (pop_en) begin
            pop_data_reg <= ram[rptr];
        end
    end

endmodule

module fifo_cu (
    input        clk,
    input        rst,
    input        push_en,   // = push & ~full
    input        pop_en,    // = pop  & ~empty
    output [4:0] wptr,
    output [4:0] rptr,
    output       full,
    output       empty
);

    // state regs
    reg [4:0] wptr_reg, wptr_next;
    reg [4:0] rptr_reg, rptr_next;
    reg       full_reg, full_next;
    reg       empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    // sequential
    always @(posedge clk) begin
        if (rst) begin
            wptr_reg  <= 5'd0;
            rptr_reg  <= 5'd0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    // combinational next-state
    always @(*) begin
        // defaults: hold
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({push_en, pop_en})

            2'b01: begin // POP only (guaranteed not empty)
                rptr_next  = rptr_reg + 5'd1;
                full_next  = 1'b0;

                // after pop, if read catches up to write -> empty
                if (wptr_reg == (rptr_reg + 5'd1))
                    empty_next = 1'b1;
            end

            2'b10: begin // PUSH only (guaranteed not full)
                wptr_next  = wptr_reg + 5'd1;
                empty_next = 1'b0;

                // after push, if write catches up to read -> full (1-slot-empty ring)
                if ((wptr_reg + 5'd1) == rptr_reg)
                    full_next = 1'b1;
            end

            2'b11: begin // PUSH + POP 동시에 (둘 다 가능하다고 보장됨)
                // 동시에 한 칸씩 이동하면 occupancy는 동일
                wptr_next = wptr_reg + 5'd1;
                rptr_next = rptr_reg + 5'd1;

                // 동시에 일어나면 "full/empty 경계"에서 빠져나오는 효과만 있음
                // (push_en/pop_en이 이미 full/empty를 고려해서 들어오므로)
                full_next  = 1'b0;
                empty_next = 1'b0;
            end

            default: begin
                // 2'b00 : 아무 동작 없음
            end

        endcase
    end

endmodule
