
`timescale 1ns/1ps

module tb_tx_fsm_ram;

    // TB signals
    logic clk;
    logic reset;
    logic canny_de;
    logic [7:0] canny_r;
    wire tx;

    // DUT
    top_uart_tx_logic dut (
        .clk      (clk),
        .reset    (reset),
        .canny_de (canny_de),
        .canny_r  (canny_r),
        .tx       (tx)
    );

    // --------------------------------------------------
    // Clock : 100MHz (10ns)
    // --------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // --------------------------------------------------
    // Stimulus
    // --------------------------------------------------
    initial begin
        // init
        reset    = 1'b1;
        canny_de = 1'b0;
        canny_r  = 8'd0;

        // reset hold
        #50;
        reset = 1'b0;

        // 32 cycles data send
        repeat (40800) begin
            @(posedge clk);
            canny_de <= 1'b1;
            canny_r  <= $random;   // ?•„ë¬? ?°?´?„°
        end

        // stop sending
        @(posedge clk);
        canny_de <= 1'b0;
        canny_r  <= 8'd0;

        // wait a bit
        #1000;
        $finish;
    end

endmodule
