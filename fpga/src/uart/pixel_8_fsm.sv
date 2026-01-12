module Pixel_8_FSM #(
    parameter DATA_WIDTH  = 8,
    parameter TOTAL_BYTES = 5100,
    parameter ADDR_WIDTH  = $clog2(TOTAL_BYTES)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  canny_de,
    input  logic [DATA_WIDTH-1:0] canny_data,
    output logic                  we,
    output logic [DATA_WIDTH-1:0] wData,
    output logic [ADDR_WIDTH-1:0] wAddr,
    output logic                  frame_tick
);
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_DATA,
        ST_ADDR,
        ST_DONE
    } state_t;

    state_t state, state_next;

    logic [DATA_WIDTH-1:0] wData_reg, wData_next;
    logic [ADDR_WIDTH-1:0] wAddr_reg, wAddr_next;
    logic frame_tick_reg, frame_tick_next;
    logic [2:0] pixel_cnt_reg, pixel_cnt_next;
    logic we_reg, we_next;

    assign wData      = wData_reg;
    assign wAddr      = wAddr_reg;
    assign frame_tick = frame_tick_reg;
    assign we         = we_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            state          <= ST_IDLE;
            wData_reg      <= '0;
            wAddr_reg      <= '0;
            frame_tick_reg <= 1'b0;
            pixel_cnt_reg  <= '0;
            we_reg         <= 1'b0;
        end else begin
            state          <= state_next;
            wData_reg      <= wData_next;
            wAddr_reg      <= wAddr_next;
            frame_tick_reg <= frame_tick_next;
            pixel_cnt_reg  <= pixel_cnt_next;
            we_reg         <= we_next;
        end
    end

    always_comb begin
        state_next      = state;
        wData_next      = wData_reg;
        wAddr_next      = wAddr_reg;
        frame_tick_next = 1'b0;
        pixel_cnt_next  = pixel_cnt_reg;
        we_next         = 1'b0;
        case (state)
            ST_IDLE: begin
                if (canny_de) begin
                    state_next                = ST_DATA;
                    wData_next[pixel_cnt_reg] = canny_data[0];
                    pixel_cnt_next            = pixel_cnt_reg + 1;
                end
            end
            ST_DATA: begin
                if (canny_de) begin
                    wData_next[pixel_cnt_reg] = canny_data[0];
                    pixel_cnt_next            = pixel_cnt_reg + 1;

                    if (pixel_cnt_reg == 3'b111) begin
                        state_next     = ST_ADDR;
                        pixel_cnt_next = '0;
                        we_next        = 1'b1;
                        if (wAddr_reg == (TOTAL_BYTES - 1)) begin
                            state_next = ST_DONE;
                        end
                    end else if (pixel_cnt_reg < 3'b111) begin
                        state_next = ST_DATA;
                    end
                end
            end
            ST_ADDR: begin
                wAddr_next = wAddr_reg + 1;
                state_next = ST_IDLE;

                if (canny_de) begin
                    wData_next[pixel_cnt_reg] = canny_data[0];
                    pixel_cnt_next            = pixel_cnt_reg + 1;
                end
            end
            ST_DONE: begin
                frame_tick_next = 1'b1;
                state_next      = ST_IDLE;
                wAddr_next      = '0;
            end
        endcase
    end
endmodule

module Pixel_FSM #(
    parameter DATA_WIDTH  = 8,
    parameter TOTAL_PIXELS = 42240,
    parameter ADDR_WIDTH  = $clog2(TOTAL_PIXELS)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  canny_de,
    input  logic [DATA_WIDTH-1:0] canny_data,
    output logic                  we,
    output logic [DATA_WIDTH-1:0] wData,
    output logic [ADDR_WIDTH-1:0] wAddr,
    output logic                  frame_tick
);
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_DATA,
        ST_DONE
    } state_t;

    state_t state, state_next;

    logic [DATA_WIDTH-1:0] wData_reg, wData_next;
    logic [ADDR_WIDTH-1:0] wAddr_reg, wAddr_next;
    logic frame_tick_reg, frame_tick_next;
    logic we_reg, we_next;

    assign wData      = wData_reg;
    assign wAddr      = wAddr_reg;
    assign frame_tick = frame_tick_reg;
    assign we         = we_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            state          <= ST_IDLE;
            wData_reg      <= '0;
            wAddr_reg      <= '0;
            frame_tick_reg <= 1'b0;
            we_reg         <= 1'b0;
        end else begin
            state          <= state_next;
            wData_reg      <= wData_next;
            wAddr_reg      <= wAddr_next;
            frame_tick_reg <= frame_tick_next;
            we_reg         <= we_next;
        end
    end

    always_comb begin
        state_next      = state;
        wData_next      = wData_reg;
        wAddr_next      = wAddr_reg;
        frame_tick_next = 1'b0;
        we_next         = 1'b0;

        case (state)
            ST_IDLE: begin
                if (canny_de) begin
                    state_next = ST_DATA;
                    wData_next = canny_data;
                    we_next    = 1'b1;
                end
            end
            ST_DATA: begin
                if (canny_de) begin
                    wData_next = canny_data;
                    we_next    = 1'b1;
                end

                if (wAddr_reg == (TOTAL_PIXELS - 1)) begin
                    state_next = ST_DONE;
                end else if (wAddr_reg < (TOTAL_PIXELS - 1)) begin
                    wAddr_next = wAddr_reg + 1;
                    state_next = ST_DATA;
                end
            end
            ST_DONE: begin
                frame_tick_next = 1'b1;
                state_next      = ST_IDLE;
                wAddr_next      = '0;
            end
        endcase
    end

endmodule


module pixel_fsm (
    input clk,
    input reset,
    input canny_de,
    input [7:0] canny_data,
    output we,
    output [7:0] wData,
    output [$clog2(176*240)-1:0] wAddr,
    output frame_tick
);

typedef enum logic [2:0] {
        ST_IDLE,
        ST_DATA,
      //  ST_ADDR,
        ST_DONE
} state;

state current_state, next_state;

reg [7:0] wData_reg, wData_next;
reg [$clog2(176*240)-1:0] wAddr_reg, wAddr_next;
reg frame_tick_reg, frame_tick_next; 
// reg [2:0]pixel_cnt_reg, pixel_cnt_next; //0~7
reg we_reg, we_next;

assign wData = wData_reg;
assign wAddr = wAddr_reg;
assign frame_tick = frame_tick_reg;
assign we = we_reg;


always @(posedge clk) begin
    if (reset) begin
        current_state <= ST_IDLE;
        wData_reg <= 8'h00;
        wAddr_reg <= '0;
        frame_tick_reg <= 1'b0;
        we_reg <= 1'b0;
    end else begin
        current_state <= next_state;
        wData_reg <= wData_next;
        wAddr_reg <= wAddr_next;
        frame_tick_reg <= frame_tick_next;
        we_reg <= we_next;
    end
end


always @(*) begin
    next_state = current_state; 
    wData_next = wData_reg;
    wAddr_next = wAddr_reg;
    frame_tick_next = 1'b0;
    we_next = 1'b0; 


    case (current_state)
        ST_IDLE: begin
            if (canny_de) begin
                next_state = ST_DATA;
                wData_next = canny_data; 
                we_next = 1'b1;
            end
        end

        ST_DATA: begin
            if (canny_de) begin
                wData_next = canny_data; 
                we_next = 1'b1;

            end 
            if(wAddr_reg == (176*240-1)) begin
                    next_state = ST_DONE;
                end 
                else if (wAddr_reg < (176*240-1)) begin
                    wAddr_next = wAddr_reg + 1;
                    next_state = ST_DATA; 
                end
        end
        ST_DONE: begin
            frame_tick_next = 1'b1; 
            next_state = ST_IDLE;
            wAddr_next = '0;
        end
    endcase
end


endmodule