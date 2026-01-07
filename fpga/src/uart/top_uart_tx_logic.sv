module top_uart_tx_logic(
    input clk,
    input reset,
    input canny_de,
    input [7:0] canny_r,
    output tx

);

    logic we;
    logic [7:0] wData;
    logic [$clog2(5100)-1:0] wAddr;
    logic frame_tick;
    logic tx_fifo_full;
    logix [7:0] tx_data;


    pixel_8_fsm U_PIXEL_8_FSM(
        .clk(clk),
        .reset(reset),
        .canny_de(canny_de),
        .canny_r(canny_r),
        .we(we),
        .wData(wData),
        .wAddr(wAddr),
        .frame_tick(frame_tick)
    );


    tx_ram U_TX_RAM (
        .clk(clk),
        .we(we), 
        .wData(wData), 
        .wAddr(wAddr), 
        .frame_tick(frame_tick),   
        .re(frame_tick&&~tx_fifo_full),
        .rData(tx_data), 
        .frame_done(frame_done)   

    );


    uart_tx_fifo U_UART_TX_FIFO(
        .clk(clk),
        .reset(reset),
        .tx_data(tx_data),
        .push(frame_tick&&~tx_fifo_full),
        .tx(tx),
        .tx_fifo_full(tx_fifo_full)
    );



endmodule