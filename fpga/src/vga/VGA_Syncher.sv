`timescale 1ns / 1ps

module VGA_Syncher(
    input  logic clk,
    input  logic reset,
    output logic h_sync,
    output logic v_sync,
    output logic DE,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel
);

    logic pclk;
    logic [9:0] h_counter, v_counter;

    pixel_counter U_Pixel_Counter(
        .clk(clk),
        .reset(reset),
        .h_counter(h_counter),
        .v_counter(v_counter)
    );

    vga_sync U_VGA_Sync(
        .h_counter(h_counter),
        .v_counter(v_counter),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );
endmodule

module pixel_counter (
    input  logic       clk,
    input  logic       reset,
    output logic [9:0] h_counter,
    output logic [9:0] v_counter
);
    localparam H_MAX = 800, V_MAX = 525;

    always_ff @(posedge clk) begin
        if (reset) begin
            h_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin
                h_counter <= 0;
            end else begin
                h_counter <= h_counter + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            v_counter <= 0;
        end else begin
            if (h_counter == H_MAX - 1) begin
                if (v_counter == V_MAX - 1) begin
                    v_counter <= 0;
                end else begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end
endmodule

module vga_sync (
    input  logic [9:0] h_counter,
    input  logic [9:0] v_counter,
    output logic       h_sync,
    output logic       v_sync,
    output logic       DE,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel
);

    // VGA Signal 640 * 480 @ 60Hz
    localparam H_Visible_area = 640;	
    localparam H_Front_porch  = 16;	
    localparam H_Sync_pulse	  = 96;	
    localparam H_Back_porch	  = 48;	

    localparam V_Visible_area = 480;
    localparam V_Front_porch  = 10;
    localparam V_Sync_pulse	  = 2;
    localparam V_Back_porch	  = 33;

    assign h_sync  = !((h_counter >= H_Visible_area + H_Front_porch) 
                     && (h_counter < H_Visible_area + H_Front_porch + H_Sync_pulse));
    assign v_sync  = !((v_counter >= V_Visible_area + V_Front_porch) 
                     && (v_counter < V_Visible_area + V_Front_porch + V_Sync_pulse));
    assign DE      = (h_counter  < H_Visible_area) && (v_counter < V_Visible_area);
    assign x_pixel = h_counter;
    assign y_pixel = v_counter;
endmodule

module ImgReader(
    input  logic                       DE,
    input  logic                 [9:0] x_pixel,
    input  logic                 [9:0] y_pixel,
    input  logic                [23:0] img,
    output logic [$clog2(640*480)-1:0] addr,
    output logic                 [7:0] r_port,
    output logic                 [7:0] g_port,
    output logic                 [7:0] b_port
);

    assign addr = DE ? (640 * y_pixel + x_pixel) : 'bz;
    assign {r_port, g_port, b_port} = DE ? {img[23:16], img[15:8], img[7:0]} : 'b0;
endmodule