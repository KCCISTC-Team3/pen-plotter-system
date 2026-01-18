`timescale 1ns / 1ps

module Capture_Controller (
    input  logic clk,            // System clock
    input  logic reset,
    input  logic pclk,           // Pixel clock (camera domain)
    input  logic cap_btn,        // Capture button input
    input  logic vsync,          // Camera vsync signal
    output logic capture_enable  // Capture enable output (pclk domain)
);

    // Button debounce
    logic cap_btn_debounced;
    Button_Debounce #(
        .SIZE(16)
    ) U_BTN_DB (
        .clk(clk),
        .reset(reset),
        .btn_in(cap_btn),
        .btn_out(cap_btn_debounced)
    );

    // clk domain signals
    logic capture_request;
    logic capture_done_synced;

    // pclk domain signals
    logic capture_request_sync1, capture_request_sync2;
    logic capture_request_synced;
    logic capture_pending;
    logic capture_done;
    logic vsync_prev;
    logic vsync_falling;

    // CDC: pclk -> clk (capture done feedback)
    logic capture_done_sync1, capture_done_sync2;

    // =========================================================================
    // Capture Request Level Signal (clk domain)
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            capture_request <= 1'b0;
        end else begin
            if (cap_btn_debounced) begin
                capture_request <= 1'b1;
            end else if (capture_done_synced) begin
                capture_request <= 1'b0;
            end
        end
    end

    // =========================================================================
    // CDC: clk -> pclk (Double FF Synchronizer)
    // =========================================================================
    always_ff @(posedge pclk) begin
        if (reset) begin
            capture_request_sync1 <= 1'b0;
            capture_request_sync2 <= 1'b0;
        end else begin
            capture_request_sync1 <= capture_request;
            capture_request_sync2 <= capture_request_sync1;
        end
    end

    assign capture_request_synced = capture_request_sync2;

    // =========================================================================
    // CDC: pclk -> clk (capture done feedback)
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            capture_done_sync1 <= 1'b0;
            capture_done_sync2 <= 1'b0;
        end else begin
            capture_done_sync1 <= capture_done;
            capture_done_sync2 <= capture_done_sync1;
        end
    end

    assign capture_done_synced = capture_done_sync2;

    // =========================================================================
    // Vsync Falling Edge Detection (pclk domain)
    // =========================================================================
    always_ff @(posedge pclk) begin
        if (reset) begin
            vsync_prev    <= 1'b1;
            vsync_falling <= 1'b0;
        end else begin
            vsync_prev    <= vsync;
            vsync_falling <= ~vsync & vsync_prev;
        end
    end

    // =========================================================================
    // Capture State Machine (pclk domain)
    // IDLE -> PENDING -> CAPTURING -> IDLE
    // =========================================================================
    always_ff @(posedge pclk) begin
        if (reset) begin
            capture_pending <= 1'b0;
            capture_enable  <= 1'b0;
            capture_done    <= 1'b0;
        end else begin
            capture_done <= 1'b0;
            if (capture_request_synced && !capture_pending && !capture_enable) begin
                capture_pending <= 1'b1;
            end else if (vsync_falling && capture_pending) begin
                capture_enable  <= 1'b1;
                capture_pending <= 1'b0;
            end else if (vsync_falling && capture_enable) begin
                capture_enable <= 1'b0;
                capture_done   <= 1'b1;
            end else if (!capture_request_synced && capture_pending) begin
                capture_pending <= 1'b0;
            end
        end
    end

endmodule
