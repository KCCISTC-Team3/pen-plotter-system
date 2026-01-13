`timescale 1ns / 1ps

module Button_Debounce #(
    parameter SIZE = 16
) (
    input  logic clk,
    input  logic reset,
    input  logic btn_in,
    output logic btn_out
);

    reg btn_in_d[1:4];  //btn delayed
    wire set;  //sync reset to zero
    reg [SIZE-1:0] o = {SIZE{1'b0}};  //counter is initialized to 0

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_in_d[1] <= 0;
            btn_in_d[2] <= 0;
            btn_in_d[3] <= 0;
            o <= 0;
        end else begin
            btn_in_d[1] <= btn_in;
            btn_in_d[2] <= btn_in_d[1];
            if (set == 1) o <= 0;  //reset counter when input is changing
            else if (o[SIZE-1] == 0)
                o <= o + 1;  //stable input time is not yet met
            else
                btn_in_d[3] <= btn_in_d[2]; //stable input time is met, catch the btn and retain.
        end
    end

    assign set = (btn_in_d[1] != btn_in_d[2])? 1 : 0; //determine when to reset counter

    always @(posedge clk or posedge reset) begin
        if (reset) btn_in_d[4] <= 0;
        else btn_in_d[4] <= btn_in_d[3];
    end
    assign btn_out = btn_in_d[3] & (~btn_in_d[4]); //debounced button pulse out

endmodule
