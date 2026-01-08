

module pixel_8_fsm (
    input clk,
    input reset,
    input canny_de,
    input [7:0] canny_r,
    output we,
    output [7:0] wData,
    output [$clog2(5100)-1:0] wAddr,
    output frame_tick
);

typedef enum logic [1:0] {
        ST_IDLE,
        ST_DATA,
        ST_DONE
} state;

state current_state, next_state;

reg [7:0] wData_reg, wData_next;
reg [$clog2(5100)-1:0] wAddr_reg, wAddr_next;
reg frame_tick_reg, frame_tick_next; 
reg [2:0]pixel_cnt_reg, pixel_cnt_next; //0~7
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
        pixel_cnt_reg <= 3'b0;
        we_reg <= 1'b0;
    end else begin
        current_state <= next_state;
        wData_reg <= wData_next;
        wAddr_reg <= wAddr_next;
        frame_tick_reg <= frame_tick_next;
        pixel_cnt_reg <= pixel_cnt_next;
        we_reg <= we_next;
    end
end


always @(*) begin
    next_state = current_state; 
    wData_next = wData_reg;
    wAddr_next = wAddr_reg;
    frame_tick_next = 1'b0;
    pixel_cnt_next = pixel_cnt_reg;
    we_next = 1'b0; 


    case (current_state)
        ST_IDLE: begin
            if (canny_de) begin
                next_state = ST_DATA;
                wData_next[pixel_cnt_reg] = canny_r[0]; 
                pixel_cnt_next = pixel_cnt_reg + 1;
            end
        end

        ST_DATA: begin
            if (canny_de) begin
                wData_next[pixel_cnt_reg] = canny_r[0]; 
                pixel_cnt_next = pixel_cnt_reg + 1;

                if (pixel_cnt_reg == 3'b111) begin
                    next_state = ST_IDLE;
                    pixel_cnt_next = 3'b0;
                    wAddr_next = wAddr_reg + 1;
                    we_next = 1'b1;
                    if(wAddr_reg == 5099) begin
                        next_state = ST_DONE; 
                    end
                end else if (pixel_cnt_reg < 3'b111) begin
                    next_state = ST_DATA; 
                end

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