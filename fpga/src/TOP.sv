`timescale 1ns / 1ps

module TOP (
    input  logic clk,
    input  logic reset,
    input  logic rx,
    output logic tx 
);

        
        logic        start_read;
        logic       w_start_read;
        wire        oe;

        logic [$clog2(240*170)-1:0] write_addr;
        logic [23:0] write_rgb_data;
        logic        write_en;

        logic [$clog2(240*170)-1:0] read_addr;
        logic [23:0] read_img_data;
        logic        DE;

        logic [7:0]  o_r, o_g, o_b;

        logic        gray_de;
        logic [7:0]  gray_r, gray_g, gray_b;

        logic        gauss_de;
        logic [7:0]  gauss_r, gauss_g, gauss_b;

        logic        sobel_de;
        logic [7:0]  sobel_r, sobel_g, sobel_b;

        logic        canny_de;
        logic [7:0]  canny_r, canny_g, canny_b;

        logic        tx_fifo_full;
        logic        tx_push;

        top_uart_rx_logic U_TOP_UART_RX_LOGIC (
            .clk(clk),
            .reset(reset),
            .rx(rx),
            .rgb_data(write_rgb_data),
            .pixel_done(write_en),
            .pixel_cnt(write_addr),
            .frame_done(w_start_read)
        );


        rx_ram U_IMG_RAM(
           .clk(clk),
           .we(write_en), //pixel_done
           .wData(write_rgb_data), 
           .wAddr(write_addr), //pixel_cnt
           .frame_done(w_start_read),
           .o_frame_done(start_read),
           .oe(oe), //read enable
           .rAddr(read_addr),
           .imgData(read_img_data)
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
            .clk(clk),
            .reset(reset),
            .start_read(start_read),
            .img(read_img_data),
            .addr(read_addr),
            .o_de(DE),
            .r_port(o_r),
            .g_port(o_g),
            .b_port(o_b)
        );

        DS_Gray #(
            .WIDTH(8),
            .BRIGHTNESS_ADD(0),
            .BRIGHTNESS_SUB(0)
        ) U_DS_Gray (
            .clk(clk),
            .rstn(!reset),
            .i_vsync(1'b0), 
            .i_hsync(1'b0),
            .i_de(DE),
            .i_r_data(o_r), .i_g_data(o_g), .i_b_data(o_b),
            .o_vsync(),
            .o_hsync(),
            .o_de(gray_de), // 1clk delay
            .o_r_data(gray_r), .o_g_data(gray_g), .o_b_data(gray_b)
        );

        Gaussian #(
            .WIDTH(8),
            .H_RES(170)
        ) U_Gaussian (
            .clk(clk),
            .rstn(!reset),
            .i_vsync(1'b0),
            .i_hsync(1'b0),
            .i_de(gray_de),
            .i_r_data(gray_r), .i_g_data(gray_g), .i_b_data(gray_b),
            .o_vsync(),
            .o_hsync(),
            .o_de(gauss_de), // 2clk delay
            .o_r_data(gauss_r), .o_g_data(gauss_g), .o_b_data(gauss_b)
        );

        Sobel #(
            .WIDTH(8),
            .H_RES(170)
        ) U_Sobel (
            .clk(clk),
            .rstn(!reset),
            .i_vsync(1'b0),
            .i_hsync(1'b0),
            .i_de(gauss_de),
            .i_r_data(gauss_r), .i_g_data(gauss_g), .i_b_data(gauss_b),
            .o_vsync(),
            .o_hsync(),
            .o_de(sobel_de), // 3clk delay
            .o_r_data(sobel_r), .o_g_data(sobel_g), .o_b_data(sobel_b)
        );

        Canny_Edge #(
            .WIDTH(8),
            .H_RES(170),
            .TH_HIGH(255),
            .TH_LOW(250)
        ) U_Canny_Edge (
            .clk(clk),
            .rstn(!reset),
            .i_vsync(1'b0),
            .i_hsync(1'b0),
            .i_de(sobel_de),
            .i_r_data(sobel_r), .i_g_data(sobel_g), .i_b_data(sobel_b),
            .o_vsync(),
            .o_hsync(),
            .o_de(canny_de), // 350clk delay
            .o_r_data(canny_r), .o_g_data(canny_g), .o_b_data(canny_b)
        );

        assign tx_push = canny_de & (~tx_fifo_full); 
        
        uart_tx_fifo U_TX_FIFO (
            .clk(clk),
            .reset(reset),
            .tx_data(canny_r),
            .push(tx_push),
            .tx(tx),
            .tx_fifo_full(tx_fifo_full)
        );

endmodule


module ImgReader(
    input  logic         clk,
    input  logic         reset,
    input  logic         start_read,  
    input  logic [23:0]  img,         
    output logic [15:0]  addr,        
    output logic         o_de,        
    output logic [7:0]   r_port,
    output logic [7:0]   g_port,
    output logic [7:0]   b_port
);

    logic [7:0] x_cnt; // 0~169 카운터
    logic [7:0] y_cnt; // 0~239 카운터
    logic       reading;

    
    always_ff @(posedge clk) begin
        if (reset) begin
            reading <= 1'b0;
        end else if (start_read) begin
            reading <= 1'b1; 
        end else if (x_cnt == 169 && y_cnt == 239) begin
            reading <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset || !reading) begin
            x_cnt <= 0;
            y_cnt <= 0;
        end else begin
            if (x_cnt == 169) begin
                x_cnt <= 0;
                if (y_cnt == 239) y_cnt <= 0;
                else y_cnt <= y_cnt + 1;
            end else begin
                x_cnt <= x_cnt + 1;
            end
        end
    end

 
 
    assign addr = reading ? (y_cnt * 170 + x_cnt) : 'h0;
 
    always_ff @(posedge clk) begin
        o_de <= reading;
    end
    assign {r_port, g_port, b_port} = o_de ? {img[23:16], img[15:8], img[7:0]} : 'b0;

endmodule

module imgRom (
    input  logic                        clk,
    input  logic [$clog2(170*240)-1:0]  addr,
    output logic [23:0]                 data
);
    logic [23:0] mem [0:255]; 

    always_ff @(posedge clk) begin
        data <= mem[addr[7:0]];
        
    end
endmodule
