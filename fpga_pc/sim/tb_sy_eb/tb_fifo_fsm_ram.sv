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

/*
module tb_fifo_fsm_ram(

    );
    
  logic        clk;
  logic        reset;
  logic        rx;
  logic        oe;
  logic [$clog2(80*120)-1:0] rAddr;
  
  wire [23:0] imgData;

  wire         empty;
  wire [7:0]   pop_data;
  wire         rx_done;
  wire [23:0] rgb_data;
  wire pixel_done;
  wire [15:0] pixel_cnt;
  wire frame_done;
  wire o_frame_done;

*/
  module tb_fifo_fsm_ram();

  // ---------------------------------------------------------
  // 1. Parameters (설계 사양에 맞춰 수정하세요)
  // ---------------------------------------------------------
  localparam DATA_WIDTH = 8;
  localparam RGB_WIDTH  = 24;
  localparam FIFO_DEPTH = 2;
  localparam IMG_WIDTH  = 8;
  localparam IMG_HEIGHT = 10;
  localparam MEM_SIZE   = IMG_WIDTH * IMG_HEIGHT;

  // ---------------------------------------------------------
  // 2. System Signals (Global)
  // ---------------------------------------------------------
  logic clk;
  logic reset;
  logic rx;
  //logic cam_mode = 1'b0; // 0: PC, 1: Camera

  // ---------------------------------------------------------
  // 3. Interconnect Signals (모듈 간 연결)
  // ---------------------------------------------------------
  // UART_RX_Top -> RX_RAM
  wire [RGB_WIDTH-1:0] wData;
  wire we;
  wire [$clog2(MEM_SIZE)-1:0] wAddr;
  wire frame_done;

  // RX_RAM -> Img_Reader
  wire frame_done_delayed;
  wire [$clog2(MEM_SIZE)-1:0] read_addr;
  wire [RGB_WIDTH-1:0] read_img_data;
  wire oe; // output enable
   wire         rx_done;

  // Img_Reader Outputs (최종 출력)
  wire DE;
  wire [7:0] o_r, o_g, o_b;

  // ---------------------------------------------------------
  // 4. Simulation / Task Variables
  // ---------------------------------------------------------
// ---------------------------------------------------------
localparam int BIT_TIME_NS  = 8680;   // 115200bps (1/115200 * 10^9)
localparam int STOP_HOLD_NS = 100;   // 스톱 비트도 1비트 시간만큼 유지
localparam int IDLE_GAP_NS  = 10000;  // 바이트 사이 여유 시간

  
  
  /*

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
*/

  UART_RX_Top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_UART_RX_Top (
        .clk       (clk),
        .reset     (reset),
        .rx        (rx),
        .cam_mode  (1'b0),  // 0: PC, 1: Camera 
        .rgb_data  (wData),
        .pixel_done(we),
        .pixel_cnt (wAddr),
        .frame_done(frame_done),
        .rx_done(rx_done)
    );

    RX_RAM #(
        .RGB_WIDTH (RGB_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_RX_RAM (
        .clk         (clk),
        .we          (we),
        .wData       (wData),
        .wAddr       (wAddr),
        .frame_done  (frame_done),
        .o_frame_done(frame_done_delayed),
        .oe          (oe),
        .rAddr       (read_addr),
        .imgData     (read_img_data)
    );

    Img_Reader #(
        .RGB_WIDTH (RGB_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Img_Reader (
        .clk       (clk),
        .reset     (reset),
        .start_read(frame_done_delayed),
        .img       (read_img_data),
        .addr      (read_addr),
        .re        (oe),
        .o_de      (DE),
        .r_port    (o_r),
        .g_port    (o_g),
        .b_port    (o_b)
    );

  always #5 clk = ~clk; // 100MHz

  int k;
  //reg [7:0] send_data;

  initial begin
    clk   = 0;
    reset = 1;
    rx    = 1;
  
    

    #20;
    reset = 0;
    #20;

    // 1) 0xAA
    send_uart(8'hAA);
    @(posedge rx_done);
    //#(IDLE_GAP_NS);

    // 2) 0x00 ~ 0x28 (0~40)
    for (k = 0; k < 240 ; k++) begin
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
