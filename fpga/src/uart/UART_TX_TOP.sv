`timescale 1ns / 1ps

module UART_TX_TOP #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter SAMPLING   = 16,
    parameter FIFO_DEPTH = 5,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input logic clk,
    input logic reset,
    input logic b_tick,
    input logic edge_tx_trig,

    // Frame Buffer read interface (Grayscale 8bit)
    output logic                  fb_re,
    output logic [ADDR_WIDTH-1:0] fb_rAddr,
    input  logic [           7:0] fb_rData,

    // Status
    output logic tx_full,
    output logic tx_busy,
    output logic sending,
    output logic frame_tx_done,

    // UART output
    output logic tx
);

    // ===== Internal Signals =====
    logic                  fifo_empty;
    logic                  fifo_pop;
    logic [DATA_WIDTH-1:0] fifo_dout;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  tx_start;

    typedef enum {
        IDLE,
        WAIT_DATA,
        WAIT_BUSY
    } state_e;

    state_e state;

    // =========================================================================
    // UART TX FSM (FIFO → UART)
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            fifo_pop <= 1'b0;
            tx_start <= 1'b0;
        end else begin
            fifo_pop <= 1'b0;
            tx_start <= 1'b0;

            case (state)
                IDLE: begin
                    if (~fifo_empty && ~tx_busy) begin
                        fifo_pop <= 1'b1;
                        state    <= WAIT_DATA;
                    end
                end
                WAIT_DATA: begin
                    tx_start <= 1'b1;
                    state    <= WAIT_BUSY;
                end
                WAIT_BUSY: begin
                    if (tx_busy) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // UART TX Controller (Frame Buffer → FIFO)
    // =========================================================================
    UART_TX_Controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_UART_TX_CONTROLLER (
        .clk          (clk),
        .reset        (reset),
        .edge_tx_trig (edge_tx_trig),
        .tx_full      (tx_full),
        .fb_re        (fb_re),
        .fb_rAddr     (fb_rAddr),
        .fb_rData     (fb_rData),
        .wr_en        (wr_en),
        .wr_data      (wr_data),
        .sending      (sending),
        .frame_tx_done(frame_tx_done)
    );

    // =========================================================================
    // TX FIFO
    // =========================================================================
    FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(FIFO_DEPTH)
    ) U_TX_FIFO (
        .clk      (clk),
        .reset    (reset),
        .push     (wr_en),
        .push_data(wr_data),
        .pop      (fifo_pop),
        .pop_data (fifo_dout),
        .full     (tx_full),
        .empty    (fifo_empty)
    );

    // =========================================================================
    // UART TX Core
    // =========================================================================
    UART_TX #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLING  (SAMPLING)
    ) U_UART_TX (
        .clk     (clk),
        .reset   (reset),
        .b_tick  (b_tick),
        .tx_start(tx_start),
        .tx_data (fifo_dout),
        .tx_busy (tx_busy),
        .tx      (tx)
    );

endmodule
