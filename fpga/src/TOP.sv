`timescale 1ns / 1ps

module TOP (
    input  logic clk,
    input  logic reset,
    input  logic rx,
    output logic tx
);

    logic                       start_read;
    logic                       w_start_read;
    wire                        oe;

    logic [$clog2(240*172)-1:0] write_addr;
    logic [               23:0] write_rgb_data;
    logic                       write_en;

    logic [$clog2(240*172)-1:0] read_addr;
    logic [               23:0] read_img_data;
    logic                       DE;

    logic [7:0] o_r, o_g, o_b;

    logic       canny_de;
    logic [7:0] canny_data;

    logic       tx_fifo_full;
    logic       tx_push;

    top_uart_rx_logic U_TOP_UART_RX_LOGIC (
        .clk       (clk),
        .reset     (reset),
        .rx        (rx),
        .rgb_data  (write_rgb_data),
        .pixel_done(write_en),
        .pixel_cnt (write_addr),
        .frame_done(w_start_read)
    );

    rx_ram U_IMG_RAM (
        .clk         (clk),
        .we          (write_en),        //pixel_done
        .wData       (write_rgb_data),
        .wAddr       (write_addr),      //pixel_cnt
        .frame_done  (w_start_read),
        .o_frame_done(start_read),
        .oe          (oe),              //read enable
        .rAddr       (read_addr),
        .imgData     (read_img_data)
    );

    top_filter #(
        .WIDTH         (8),
        .H_RES         (172),
        .BRIGHTNESS_ADD(30),
        .BRIGHTNESS_SUB(30),
        .TH_HIGH       (230),
        .TH_LOW        (180)
    ) U_TOP_FILTER (
        .clk     (clk),
        .rstn    (!reset),
        .i_vsync (1'b0),
        .i_hsync (1'b0),
        .i_de    (DE),
        .i_r_data(o_r),
        .i_g_data(o_g),
        .i_b_data(o_b),
        .o_vsync (),
        .o_hsync (),
        .o_de    (canny_de),
        .o_data  (canny_data)
    );

    /*Simple_DP_RAM U_FRAME_BUFFER (
            .clk(clk),
            .we(write_en),
            .waddr(write_addr),
            .wdata(write_rgb_data),
            .raddr(read_addr),
            .rdata(read_img_data)
        );
        */

    ImgReader U_ImgReader (
        .clk       (clk),
        .reset     (reset),
        .start_read(start_read),
        .img       (read_img_data),
        .addr      (read_addr),
        .re        (oe),
        .o_de      (DE),
        .r_port    (o_r),
        .g_port    (o_g),
        .b_port    (o_b)
    );
    
    
     uart_tx_fifo U_UART_TX_FIFO (
        .clk         (clk),
        .reset       (reset),
        .tx_data     (canny_data),
        .push        (canny_de),
        .tx          (tx),
        .tx_fifo_full()
    );
    
    /*

    top_uart_tx_logic U_TOP_UART_TX_LOGIC (
        .clk       (clk),
        .reset     (reset),
        .canny_de  (canny_de),
        .canny_data(canny_data),
        .tx        (tx)
    );
    
    */

endmodule

module ImgReader (
    input  logic        clk,
    input  logic        reset,
    input  logic        start_read,
    input  logic [23:0] img,
    output logic [15:0] addr,
    output logic        o_de,
    output logic        re,
    output logic [ 7:0] r_port,
    output logic [ 7:0] g_port,
    output logic [ 7:0] b_port
);

    logic [ 7:0] x_cnt;  // 0~171 ì¹´ìš´?„°
    logic [ 7:0] y_cnt;  // 0~239 ì¹´ìš´?„°
    logic        reading;
    logic [23:0] reg_rgb_data;


    always_ff @(posedge clk) begin
        if (reset) begin
            reading <= 1'b0;
        end else if (start_read) begin
            reading <= 1'b1;
        end else if (x_cnt == 171 && y_cnt == 239) begin
            reading <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset || !reading) begin
            x_cnt <= 0;
            y_cnt <= 0;
        end else begin
            if (x_cnt == 171) begin
                x_cnt <= 0;
                if (y_cnt == 239) y_cnt <= 0;
                else y_cnt <= y_cnt + 1;
            end else begin
                x_cnt <= x_cnt + 1;
            end
        end
    end

    assign addr = reading ? (y_cnt * 172 + x_cnt) : 'h0;

    always_ff @(posedge clk) begin
        re   <= reading;
        o_de <= re;
    end

    assign reg_rgb_data = re ? {img[23:16], img[15:8], img[7:0]} : 'b0;
    assign {r_port, g_port, b_port} = o_de ? reg_rgb_data : 'b0;


endmodule

module imgRom (
    input  logic                       clk,
    input  logic [$clog2(172*240)-1:0] addr,
    output logic [               23:0] data
);
    logic [23:0] mem[0:255];

    always_ff @(posedge clk) begin
        data <= mem[addr[7:0]];
    end
endmodule
