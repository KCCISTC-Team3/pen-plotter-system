`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 11:40:45
// Design Name: 
// Module Name: tb_rx_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_uart_rx_fifo;

  logic        clk;
  logic        reset;
  logic        rx;
  
  wire         empty;
  wire [7:0]   pop_data;
  wire         rx_done;

  localparam int BIT_TICKS = 16;
  localparam int DATA_BITS = 8;

  uart_rx_fifo dut (
    .clk      (clk),
    .reset    (reset),
    .rx       (rx),
    .empty    (empty),
    .pop_data (pop_data),
    .rx_done  (rx_done)
  );

    parameter UART_TX_DELAY = (100_000_000 / 9600) * 12 * 10;
    reg [7:0] send_data;

    always #5 clk = ~clk;

    initial begin
        #0;
        clk   = 0;
        reset   = 1;
        rx    = 1;
        
        #10;
        reset = 0;
        #10;
        // uart frame
        send_data = 8'h30;
        send_uart(send_data);
        wait (rx_done);
        
        // uart frame
        send_data = 8'h31;
        send_uart(send_data);

        wait (rx_done);
       
        send_data = 8'h32;
        send_uart(send_data);
 
        wait (rx_done);


        #(UART_TX_DELAY);
        

        #1000;
        $stop;
    end

    task send_uart(input [7:0] send_data);
        integer i;
        begin
            // start bit
            rx = 0;
            #(104166);  

            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(104166);  // uart 9600bps bit time 
            end
            // stopbit
            rx = 1;
            #(1000);  // uart 9600bps bit time
        end
    endtask

    
endmodule
