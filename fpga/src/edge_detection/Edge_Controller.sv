`timescale 1ns / 1ps

module Edge_Controller #(
    parameter IMG_WIDTH  = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic clk,
    input  logic reset,
    input  logic start_edge_trig,
    output logic edge_done,
    output logic processing,

    // Input Frame Buffer Read
    output logic                  cap_fb_re,
    output logic [ADDR_WIDTH-1:0] cap_fb_rAddr,
    input  logic [          15:0] cap_fb_rData,

    // Edge Frame Buffer Write
    output logic                  edge_fb_we,
    output logic [ADDR_WIDTH-1:0] edge_fb_wAddr,
    output logic [           7:0] edge_fb_wData,

    // Edge Detection Interface
    output logic       edge_vsync,
    output logic       edge_hsync,
    output logic       edge_de,
    output logic [7:0] edge_r,
    output logic [7:0] edge_g,
    output logic [7:0] edge_b,
    input  logic       edge_o_vsync,
    input  logic       edge_o_hsync,
    input  logic       edge_o_de,
    input  logic [7:0] edge_o_data
);

    localparam EXPECTED_OUTPUT = IMG_WIDTH * (IMG_HEIGHT - 7);

    typedef enum {
        IDLE,
        WAIT_VSYNC,
        SEND_FRAME,
        WAIT_EDGE_DONE,
        DONE
    } state_e;

    state_e state, state_next;

    logic [15:0] pixel_cnt;
    logic [9:0] x_cnt, y_cnt;
    logic [ADDR_WIDTH-1:0] edge_pixel_cnt;
    logic [          15:0] wait_timeout;
    logic vsync_pulse, hsync_pulse, hsync_delayed;
    logic [4:0] r5, b5;
    logic [5:0] g6;
    logic [7:0] r8, g8, b8;

    // ===== Rising Edge Detection =====
    logic start_edge_trig_prev;
    logic start_edge_trig_rise;

    assign {r5, g6, b5} = cap_fb_rData;
    assign r8           = {r5, r5[4:2]};
    assign g8           = {g6, g6[5:4]};
    assign b8           = {b5, b5[4:2]};

    // =========================================================================
    // Rising Edge Detection for start_edge_trig
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            start_edge_trig_prev <= 1'b0;
        end else begin
            start_edge_trig_prev <= start_edge_trig;
        end
    end

    assign start_edge_trig_rise = start_edge_trig && !start_edge_trig_prev;

    // =========================================================================
    // State Machine
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end

    always_comb begin
        state_next = state;

        case (state)
            IDLE: begin
                if (start_edge_trig_rise) begin
                    state_next = WAIT_VSYNC;
                end
            end
            WAIT_VSYNC: begin
                state_next = SEND_FRAME;
            end
            SEND_FRAME: begin
                if (pixel_cnt == IMG_WIDTH * IMG_HEIGHT - 1) begin
                    state_next = WAIT_EDGE_DONE;
                end
            end
            WAIT_EDGE_DONE: begin
                if ((edge_pixel_cnt >= EXPECTED_OUTPUT - 100) || (wait_timeout > 50000)) begin
                    state_next = DONE;
                end
            end
            DONE: begin
                state_next = IDLE;
            end
        endcase
    end

    // =========================================================================
    // Timeout Counter
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset || state != WAIT_EDGE_DONE) begin
            wait_timeout <= '0;
        end else begin
            wait_timeout <= wait_timeout + 1;
        end
    end

    // =========================================================================
    // Pixel Counter
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset || state == IDLE) begin
            pixel_cnt <= '0;
            x_cnt     <= '0;
            y_cnt     <= '0;
        end else if (state == SEND_FRAME) begin
            if (pixel_cnt < IMG_WIDTH * IMG_HEIGHT - 1) begin
                pixel_cnt <= pixel_cnt + 1;
                if (x_cnt == IMG_WIDTH - 1) begin
                    x_cnt <= '0;
                    y_cnt <= y_cnt + 1;
                end else begin
                    x_cnt <= x_cnt + 1;
                end
            end
        end
    end

    // =========================================================================
    // Edge Output Pixel Counter
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset || state == IDLE) begin
            edge_pixel_cnt <= '0;
        end else if (edge_o_de) begin
            edge_pixel_cnt <= edge_pixel_cnt + 1;
        end
    end

    // =========================================================================
    // Sync Pulse Generation
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset || state == IDLE) begin
            vsync_pulse <= 1'b0;
            hsync_pulse <= 1'b0;
        end else begin
            vsync_pulse <= (state == WAIT_VSYNC);
            hsync_pulse <= (state == SEND_FRAME && x_cnt == IMG_WIDTH - 1);
        end
    end

    always_ff @(posedge clk) begin
        if (reset || state == IDLE) begin
            hsync_delayed <= 1'b0;
        end else begin
            hsync_delayed <= hsync_pulse;
        end
    end

    // =========================================================================
    // Frame Buffer Read Control
    // =========================================================================
    assign cap_fb_re    = (state == SEND_FRAME);
    assign cap_fb_rAddr = pixel_cnt;

    // =========================================================================
    // Edge Detection Input
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset || state == IDLE) begin
            edge_vsync <= 1'b0;
            edge_hsync <= 1'b0;
            edge_de    <= 1'b0;
            edge_r     <= '0;
            edge_g     <= '0;
            edge_b     <= '0;
        end else begin
            edge_vsync <= vsync_pulse;
            edge_hsync <= hsync_delayed;
            edge_de    <= (state == SEND_FRAME) && !vsync_pulse;

            if (state == SEND_FRAME) begin
                edge_r <= r8;
                edge_g <= g8;
                edge_b <= b8;
            end else begin
                edge_r <= '0;
                edge_g <= '0;
                edge_b <= '0;
            end
        end
    end

    // =========================================================================
    // Done Signal Generation
    // =========================================================================
    logic [3:0] done_cnt;

    always_ff @(posedge clk) begin
        if (reset) begin
            done_cnt <= '0;
        end else begin
            case (state)
                IDLE: begin
                    done_cnt <= '0;
                end
                DONE: begin
                    if (done_cnt < 15) done_cnt <= done_cnt + 1;
                end
                default: ;
            endcase
        end
    end

    // =========================================================================
    // Edge Frame Buffer Write
    // =========================================================================
    assign edge_fb_we    = edge_o_de;
    assign edge_fb_wAddr = edge_pixel_cnt;
    assign edge_fb_wData = edge_o_data;

    // =========================================================================
    // Status Outputs
    // =========================================================================
    assign processing = (state != IDLE && state != DONE);
    assign edge_done  = (done_cnt > 0 && done_cnt <= 10);

endmodule
