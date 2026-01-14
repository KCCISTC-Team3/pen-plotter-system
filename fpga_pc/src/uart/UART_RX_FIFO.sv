`timescale 1ns / 1ps

module UART_RX_FIFO #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 5
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  rx,
    output logic                  empty,
    output logic [DATA_WIDTH-1:0] pop_data,
    output logic                  rx_done
);
    logic                  b_tick;
    logic [DATA_WIDTH-1:0] rx_data;
    logic [DATA_WIDTH-1:0] w_pop_data;
    logic                  w_rx_done;
    
    assign rx_done = w_rx_done;

    Tick_Gen_16 U_Tick_Gen (
        .clk     (clk),
        .reset   (reset),
        .b_16tick(b_tick)
    );

    UART_RX #(
        .DATA_WIDTH(DATA_WIDTH)
    ) U_UART_RX (
        .clk     (clk),
        .reset   (reset),
        .b_16tick(b_tick),
        .rx      (rx),
        .rx_data (rx_data),
        .rx_done (w_rx_done),
        .rx_busy ()
    );

    FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(FIFO_DEPTH)
    ) U_RX_FIFO (
        .clk      (clk),
        .reset    (reset),
        .push_data(rx_data),
        .push     (w_rx_done),
        .pop      (~empty),
        .pop_data (w_pop_data),
        .full     (),
        .empty    (empty)
    );

    // ---------------------------------------------------------
    // 3. Data Latch Logic (데이터 유지 로직)
    // ---------------------------------------------------------
    // empty가 아닐 때(새 데이터가 나왔을 때)만 pop_data를 업데이트합니다.
    // 이렇게 하면 FIFO가 비더라도 마지막에 읽었던 데이터가 계속 유지됩니다.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pop_data <= '0;
        end else if (~empty) begin
            pop_data <= w_pop_data;
        end
        // else: empty일 때는 이전 pop_data 값을 그대로 유지함
    end

endmodule
