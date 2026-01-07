`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 20:36:26
// Design Name: 
// Module Name: tb_fifo_fsm_ram
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


module tb_fifo_fsm_ram(

    );
    
  logic        clk;
  logic        reset;
  logic        rx;
  logic        oe;
  logic [$clog2(240*170)-1:0] rAddr;
  
  wire [23:0] imgData;

  wire         empty;
  wire [7:0]   pop_data;
  wire         rx_done;
  wire [23:0] rgb_data;
  wire pixel_done;
  wire [15:0] pixel_cnt;
  wire frame_done;
  wire o_frame_done;
  

  uart_rx_fifo dut (
    .clk      (clk),
    .reset    (reset),
    .rx       (rx),
    .empty    (empty),
    .pop_data (pop_data),
    .rx_done  (rx_done)
  );
  
  data_assembly_fsm dut2(
    .clk(clk),
    .reset(reset),
    .empty(empty),
    .pop_data(pop_data),
    .rgb_data(rgb_data),
    .pixel_done(pixel_done), // we
    .pixel_cnt(pixel_cnt), // addr 0 ~ 40799
    .frame_done(frame_done)
    );
    
    
    img_ram dut_3 (
    .clk(clk),
    .we(pixel_done), //pixel_done
    .wData(rgb_data), 
    .wAddr(pixel_cnt), //pixel_cnt
    .frame_done(frame_done),
    .o_frame_done(o_frame_done),
    .oe(oe),
    .rAddr(rAddr), 
    .imgData(imgData)  
);

  always #5 clk = ~clk; // 100MHz

  localparam int BIT_TIME_NS  = 104_166; // 9600bps ideal
  localparam int STOP_HOLD_NS = 1_000;   // 너 원래 TB 스타일 유지
  localparam int IDLE_GAP_NS  = 20_000;  // 프레임 간 약간 띄우기(원하면 조절)

  int unsigned k;
  reg [7:0] send_data;

  initial begin
    clk   = 0;
    reset = 1;
    rx    = 1;
    oe =0;
    rAddr = 0;
    

    #20;
    reset = 0;
    #20;

    // 1) 0xAA
    send_uart(8'hAA);
    @(posedge rx_done);
    //#(IDLE_GAP_NS);

    // 2) 0x00 ~ 0x28 (0~40)
    for (k = 0; k <= 40; k++) begin
      send_uart(k[7:0]);
      @(posedge rx_done);
      //#(IDLE_GAP_NS);
    end

    #1000;
    $stop;
  end

  task send_uart(input [7:0] data);
    integer i;
    begin
      // start bit
      rx = 1'b0;
      #(BIT_TIME_NS);

      // data bits LSB first
      for (i = 0; i < 8; i = i + 1) begin
        rx = data[i];
        #(BIT_TIME_NS);
      end

      // stop bit (idle high)
      rx = 1'b1;
      #(STOP_HOLD_NS);
    end
  endtask
endmodule
