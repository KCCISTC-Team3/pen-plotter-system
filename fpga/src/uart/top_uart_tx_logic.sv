module top_uart_tx_logic (
    input  logic       clk,
    input  logic       reset,
    input  logic       canny_de,
    input  logic [7:0] canny_data,
    output logic       tx

);

    logic                    we;
    logic [             7:0] wData;
    logic [$clog2(176)-1:0] wAddr;
    logic                    frame_tick;
    logic                    tx_fifo_full;
    logic [             7:0] tx_data;
    logic                   tx_busy;
    logic                   tx_done;
    logic                   frame_done;
    logic                   w_b_tick;
    logic                 start_trig;


    pixel_fsm U_PIXEL_8_FSM (
        .clk       (clk),
        .reset     (reset),
        .canny_de  (canny_de),
        .canny_data(canny_data),
        .we        (we),
        .wData     (wData),
        .wAddr     (wAddr),
        .frame_tick(frame_tick)
    );

    tx_ram U_TX_RAM (
        .clk       (clk),
        .reset     (reset),
        .we        (we),
        .wData     (wData),
        .wAddr     (wAddr),
        .frame_tick(frame_tick),
        .re        (frame_tick|| tx_done),
        .rData     (tx_data),
        .frame_done(frame_done)
    );

     tick_gen_16 U_BOARD_TICK_GEN (
    .clk(clk),
    .rst(reset),
    .b_16tick(w_b_tick)
    );

    uart_tx U_tx(
    .clk(clk),
    .rst(reset),
    .start_trig(start_trig),
    .tx_data(tx_data),
    .b_16tick(w_b_tick),
    .tx(tx),
    .tx_busy(tx_busy),
    .tx_done(tx_done)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            start_trig <= 1'b0;
            // reset logic if needed
        end else begin
            start_trig <= frame_tick || (((~tx_busy) && tx_done)&&frame_done);
        end
    end


/*
    uart_tx_fifo U_UART_TX_FIFO (
        .clk         (clk),
        .reset       (reset),
        .tx_data     (tx_data),
        .push        (frame_done && ~tx_fifo_full),
        .tx          (tx),
        .tx_fifo_full(tx_fifo_full)
    );

    */

endmodule

