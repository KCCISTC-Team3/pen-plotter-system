`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 15:52:40
// Design Name: 
// Module Name: btn_debounce
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

module Button_Debounce #(
    parameter SIZE = 16
)(
    input clk,
    input rst,
    input btn_in,
    output btn_out_pulse
);

reg btn_in_d [1:4]; //btn delayed
wire set; //sync reset to zero
reg [SIZE-1:0] o = {SIZE{1'b0}}; //counter is initialized to 0

always @(posedge clk or posedge rst)
begin
   if (rst) begin
      btn_in_d[1] <= 0;
      btn_in_d[2] <= 0;
      btn_in_d[3] <= 0;
      o <= 0;
   end
   else begin
      btn_in_d[1] <= btn_in;
      btn_in_d[2] <= btn_in_d[1];
      if (set == 1) o <= 0; //reset counter when input is changing
      else if (o[SIZE-1] == 0) o<=o+1; //stable input time is not yet met
      else btn_in_d[3] <= btn_in_d[2]; //stable input time is met, catch the btn and retain.
   end
end


assign set = (btn_in_d[1] != btn_in_d[2])? 1 : 0; //determine when to reset counter

always @(posedge clk or posedge rst) begin
   if (rst) btn_in_d[4] <= 0;
   else btn_in_d[4] <= btn_in_d[3];
end
assign btn_out_pulse = btn_in_d[3] & (~btn_in_d[4]); //debounced button pulse out

endmodule
