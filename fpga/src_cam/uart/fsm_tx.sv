

module uart_tx_fsm #(
    parameter DATA_WIDTH  = 8,
    parameter TOTAL_BYTES = 176*240,
    parameter ADDR_WIDTH  = $clog2(TOTAL_BYTES)
) (
    input logic clk,
    input logic reset,
    input logic start_btn,
    input logic [DATA_WIDTH*3-1:0] rData,
    input logic tx_fifo_full,
    output logic [DATA_WIDTH-1:0] push_data,
    output logic [ADDR_WIDTH-1:0] rAddr,
    output logic oe,
    output logic push_en,
    output logic  one_pixel_done // tb용
);

     typedef enum logic [2:0] {
        ST_IDLE,
        ST_DATA_WAIT,
        ST_R_DATA,
        ST_G_DATA,
        ST_B_DATA,
        ST_FRAME_DONE
    } state_t;

    state_t state, state_next;

    reg [DATA_WIDTH-1:0] push_data_reg, push_data_next;
    assign push_data = push_data_reg;

    reg [ADDR_WIDTH-1:0] rAddr_reg, rAddr_next;
    assign rAddr = rAddr_reg;

    reg oe_reg, oe_next;
    assign oe = oe_reg;


// r data가 이전값바로 갱신하는 걸 방지하기위해
// en 을 계속 1로 만들지 않도록
    logic data_start_en, next_color_en , next_data_en;
    assign next_data_en = (state == ST_DATA_WAIT) ? 1'b1 : 1'b0 ;

    assign next_color_en = (!tx_fifo_full && (oe_reg == 1'b1)); // g,b 용
    assign data_start_en = (next_data_en && next_color_en );

/*
    always_ff @( posedge clk ) begin : blockName
        if(reset) next_data_en <= 0;
        else next_data_en <= (!tx_fifo_full && (oe_reg == 1'b1) && data_start_en);
    end
*/
    logic  one_pixel_done_next,  one_pixel_done_reg;
    assign  one_pixel_done =  one_pixel_done_reg;

    logic push_en_reg, push_en_next;
    assign push_en = push_en_reg;




    always_ff @(posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
            push_data_reg <= '0;
            rAddr_reg <= '0;
            oe_reg <= 1'b0;
            one_pixel_done_reg <= 1'b0;
            push_en_reg <= 1'b0;
        end else begin
            state <= state_next;
            push_data_reg <= push_data_next;
            rAddr_reg <= rAddr_next;
            oe_reg <= oe_next;
            one_pixel_done_reg <=  one_pixel_done_next;
            push_en_reg <= push_en_next;
        end
    end


    always_comb begin
        state_next = state;
        rAddr_next      = rAddr_reg;   
        oe_next         = oe_reg;
        push_data_next  = push_data_reg;
        one_pixel_done_next =  1'b0; // 1tick
        push_en_next = push_en_reg;

        case (state)
            ST_IDLE: begin
                push_en_next = 1'b0;
                if (start_btn) begin
                    state_next = ST_DATA_WAIT;
                    push_data_next = 8'hAA;
                    oe_next = 1'b1;
                    rAddr_next = '0;
                    push_en_next = 1'b1;
                end
            end

            ST_DATA_WAIT: begin
                if(data_start_en) begin
                    push_data_next = rData[23:16];
                    state_next = ST_R_DATA;
                    push_en_next = 1'b1;
                end
            end

            ST_R_DATA: begin
                if(next_color_en) begin
                    push_data_next = rData[15:8];
                    state_next = ST_G_DATA;
                    push_en_next = 1'b1;
                end


            end

            ST_G_DATA: begin
                if(next_color_en) begin
                    push_data_next = rData[7:0];
                    state_next = ST_B_DATA;
                    push_en_next = 1'b1;
                end
            end
            ST_B_DATA: begin
                if(next_color_en) begin
                    if(rAddr_reg == (TOTAL_BYTES -1)) begin
                        state_next = ST_FRAME_DONE;
                        rAddr_next = '0;
                        oe_next = 1'b0;
                        one_pixel_done_next = 1'b1;
                        push_en_next = 1'b0;
                    end else begin
                        rAddr_next = rAddr_reg + 1;
                        state_next = ST_DATA_WAIT;
           //             push_data_next = rData[23:16];
                        one_pixel_done_next = 1'b1;
                        push_en_next = 1'b0;
                    end
                end
            end 
            ST_FRAME_DONE: begin
                state_next = ST_IDLE;
            end

    endcase

    end

    
endmodule