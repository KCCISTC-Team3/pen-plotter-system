`timescale 1ns / 1ps

module UART_RX_CMD #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input logic clk,
    input logic reset,

    // UART RX Interface
    output logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] rx_data,
    input  logic                  rx_empty,

    // Command & Mode Control
    output logic start_edge_trig,
    output logic edge_input_sel,

    // TX Done signal
    input logic frame_tx_done,

    // PC Image Frame Buffer write
    output logic                  pc_img_fb_we,
    output logic [ADDR_WIDTH-1:0] pc_img_fb_wAddr,
    output logic [          15:0] pc_img_fb_wData,

    // Status
    output logic receiving
);

    // ===== Command Definitions =====
    localparam CMD_PC_MODE     = 8'hAA;  // PC Mode
    localparam CMD_CAMERA_MODE = 8'hBB;  // Camera Mode

    localparam TOTAL_BYTES    = IMG_WIDTH * IMG_HEIGHT * 3;
    localparam BYTE_CNT_WIDTH = $clog2(TOTAL_BYTES);

    // ===== State Definition =====
    typedef enum logic [2:0] {
        IDLE,
        RX_CMD,
        START_CAM_CAPTURE,
        RECEIVE_IMAGE,
        WRITE_PIXEL,
        WAIT_TX_DONE
    } state_e;

    state_e state, state_next;

    // ===== Mode Register =====
    logic mode_reg;  // 0: Camera, 1: PC

    // ===== Image Reception =====
    logic [BYTE_CNT_WIDTH-1:0] byte_cnt;
    logic [    ADDR_WIDTH-1:0] pixel_addr;
    logic [  DATA_WIDTH-1:0] r_byte, g_byte, b_byte;
    logic [              1:0] rgb_phase;  // 0: R, 1: G, 2: B

    // =========================================================================
    // State Machine
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            mode_reg <= 1'b0;
        end else begin
            state <= state_next;
            if (state == RX_CMD) begin
                if (rx_data == CMD_PC_MODE) mode_reg <= 1'b1;
                else if (rx_data == CMD_CAMERA_MODE) mode_reg <= 1'b0;
            end
        end
    end

    always_comb begin
        state_next      = state;
        rd_en           = 1'b0;
        start_edge_trig = 1'b0;

        case (state)
            IDLE: begin
                if (~rx_empty) begin
                    rd_en      = 1'b1;
                    state_next = RX_CMD;
                end
            end
            RX_CMD: begin
                if (rx_data == CMD_CAMERA_MODE) begin
                    state_next = START_CAM_CAPTURE;
                end else if (rx_data == CMD_PC_MODE) begin
                    state_next = RECEIVE_IMAGE;
                end else begin
                    state_next = IDLE;
                end
            end
            START_CAM_CAPTURE: begin
                start_edge_trig = 1'b1;
                state_next      = WAIT_TX_DONE;
            end
            RECEIVE_IMAGE: begin
                if (~rx_empty) begin
                    rd_en      = 1'b1;
                    state_next = WRITE_PIXEL;
                end
            end
            WRITE_PIXEL: begin
                if (byte_cnt >= TOTAL_BYTES - 1) begin
                    start_edge_trig = 1'b1;
                    state_next      = WAIT_TX_DONE;
                end else begin
                    state_next = RECEIVE_IMAGE;
                end
            end
            WAIT_TX_DONE: begin
                if (frame_tx_done) begin
                    state_next = IDLE;
                end
            end
        endcase
    end

    // =========================================================================
    // Image Reception Logic
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset || state == RX_CMD) begin
            byte_cnt   <= '0;
            pixel_addr <= '0;
            rgb_phase  <= 2'd0;
            r_byte     <= '0;
            g_byte     <= '0;
            b_byte     <= '0;
        end else if (state == WRITE_PIXEL) begin
            // Store byte
            case (rgb_phase)
                2'd0: r_byte <= rx_data;  // R
                2'd1: g_byte <= rx_data;  // G
                2'd2: b_byte <= rx_data;  // B
            endcase

            // Increment counters
            byte_cnt <= byte_cnt + 1;

            if (rgb_phase == 2'd2) begin
                rgb_phase  <= 2'd0;
                pixel_addr <= pixel_addr + 1;
            end else begin
                rgb_phase <= rgb_phase + 1;
            end
        end
    end

    // =========================================================================
    // PC Image Frame Buffer Write
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            pc_img_fb_we    <= 1'b0;
            pc_img_fb_wAddr <= '0;
            pc_img_fb_wData <= '0;
        end else if (state == WRITE_PIXEL && rgb_phase == 2'd2) begin
            // Write when B byte is stored
            pc_img_fb_we    <= 1'b1;
            pc_img_fb_wAddr <= pixel_addr;
            // RGB888 → RGB565
            pc_img_fb_wData <= {r_byte[7:3], g_byte[7:2], b_byte[7:3]};
        end else begin
            pc_img_fb_we <= 1'b0;
        end
    end

    // =========================================================================
    // Status Output
    // =========================================================================
    assign receiving      = (state == RECEIVE_IMAGE || state == WRITE_PIXEL);
    assign edge_input_sel = mode_reg;

endmodule