`timescale 1ns / 1ps


// frome uart_rx_fifo to data_assembly_fsm

module top_uart_rx_logic(
    input        clk,
    input        reset,
    input        rx,
    input         cam_mode, // 1: camera mode, 0: uart mode
    output [23:0] rgb_data,
    output  reg   pixel_done, // we
    output  reg [15:0] pixel_cnt, // addr 0 ~ 40799
    output  reg     frame_done
    );

    wire [7:0] pop_data;
    wire empty;
    wire rx_done;

    uart_rx_fifo U_UART_RX_FIFO(
    .clk(clk),
    .reset(reset),
    .rx(rx),
    .empty(empty),
    .pop_data(pop_data),
    .rx_done()
    );

    data_assembly_fsm U_DATA_ASSEMBLY_FSM(
    .clk(clk),
    .reset(reset),
    .empty(empty),
    .cam_mode(cam_mode),
    .pop_data(pop_data),
    .rgb_data(rgb_data),
    .pixel_done(pixel_done),
    .pixel_cnt(pixel_cnt),
    .frame_done(frame_done)
    );


endmodule
