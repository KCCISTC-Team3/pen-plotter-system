`timescale 1ns / 1ps

module PenPlotter_System (
    input logic clk,
    input logic reset,

    // OV7670 Camera
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    output tri         SCL,
    inout  tri         SDA,

    // Button
    input logic cap_btn,

    // LED
    output logic led_capture,
    output logic led_sending,
    output logic led_edge_processing,
    output logic led_receiving,

    // UART
    input  logic rx,
    output logic tx,

    // HDMI TMDS out
    output wire       TMDS_Clk_p,
    output wire       TMDS_Clk_n,
    output wire [2:0] TMDS_Data_p,
    output wire [2:0] TMDS_Data_n
);

    // ===== Parameters =====
    localparam DATA_WIDTH = 8;
    localparam IMG_WIDTH = 176;
    localparam IMG_HEIGHT = 240;
    localparam CAM_WIDTH = 320;
    localparam CAM_HEIGHT = 240;
    localparam ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT);

    localparam CLK_FREQ = 125_000_000;
    localparam BAUDRATE = 115200;
    localparam SAMPLING = 16;
    localparam FIFO_DEPTH = 5;

    localparam EDGE_TH_HIGH = 40;
    localparam EDGE_TH_LOW = 20;

    // ===== Camera System Signals =====
    logic                  pixel_clk;
    logic [ADDR_WIDTH-1:0] video_fb_rAddr;
    logic [          15:0] video_fb_rData;
    logic [ADDR_WIDTH-1:0] capture_fb_rAddr_vga;
    logic [          15:0] capture_fb_rData_vga;
    logic                  capture_fb_re_edge;
    logic [ADDR_WIDTH-1:0] capture_fb_rAddr_edge;
    logic [          15:0] capture_fb_rData_edge;
    logic                  pc_img_fb_re;
    logic [ADDR_WIDTH-1:0] pc_img_fb_rAddr;
    logic [          15:0] pc_img_fb_rData;
    logic                  pc_img_fb_we;
    logic [ADDR_WIDTH-1:0] pc_img_fb_wAddr;
    logic [          15:0] pc_img_fb_wData;

    // ===== Edge System Signals =====
    logic                  start_edge_trig;
    logic                  edge_input_sel;
    logic                  edge_done;
    logic                  processing;
    logic                  edge_fb_re;
    logic [ADDR_WIDTH-1:0] edge_fb_rAddr;
    logic [           7:0] edge_fb_rData;

    // ===== UART System Signals =====
    logic                  edge_tx_trig;
    logic                  frame_tx_done;
    logic                  sending;
    logic                  receiving;

    // ===== Misc =====
    logic                  led_cap_reg;

    // =========================================================================
    // Pixel Clock & UART Start Trigger
    // =========================================================================
    assign xclk         = pixel_clk;
    assign edge_tx_trig = edge_done;

    // =========================================================================
    // LED Control
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            led_cap_reg <= 1'b0;
        end else begin
            if (start_edge_trig) begin
                led_cap_reg <= ~led_cap_reg;
            end
        end
    end

    assign led_capture         = led_cap_reg;
    assign led_sending         = sending;
    assign led_edge_processing = processing;
    assign led_receiving       = receiving;

    // =========================================================================
    // Camera System
    // =========================================================================
    Camera_System #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .CAM_WIDTH (CAM_WIDTH),
        .CAM_HEIGHT(CAM_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_Camera_System (
        .clk                  (clk),
        .reset                (reset),
        .pclk                 (pclk),
        // Camera interface
        .href                 (href),
        .vsync                (vsync),
        .data                 (data),
        .SCL                  (SCL),
        .SDA                  (SDA),
        // Capture control
        .cap_btn              (cap_btn),
        // Video FB (VGA)
        .vga_clk              (pixel_clk),
        .video_fb_rAddr       (video_fb_rAddr),
        .video_fb_rData       (video_fb_rData),
        // Capture FB (VGA)
        .capture_fb_rAddr_vga (capture_fb_rAddr_vga),
        .capture_fb_rData_vga (capture_fb_rData_vga),
        // Capture FB (Edge)
        .capture_fb_re_edge   (capture_fb_re_edge),
        .capture_fb_rAddr_edge(capture_fb_rAddr_edge),
        .capture_fb_rData_edge(capture_fb_rData_edge),
        // PC Image FB (Edge)
        .pc_img_fb_re         (pc_img_fb_re),
        .pc_img_fb_rAddr      (pc_img_fb_rAddr),
        .pc_img_fb_rData      (pc_img_fb_rData),
        // PC Image FB (UART)
        .pc_img_fb_we         (pc_img_fb_we),
        .pc_img_fb_wAddr      (pc_img_fb_wAddr),
        .pc_img_fb_wData      (pc_img_fb_wData)
    );

    // =========================================================================
    // Display System
    // =========================================================================
    Display_System #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_Display_System (
        .clk             (clk),
        .reset           (reset),
        .pixel_clk       (pixel_clk),
        // Video FB read
        .video_fb_rAddr  (video_fb_rAddr),
        .video_fb_rData  (video_fb_rData),
        // Capture FB read
        .capture_fb_rAddr(capture_fb_rAddr_vga),
        .capture_fb_rData(capture_fb_rData_vga),
        // HDMI output
        .TMDS_Clk_p      (TMDS_Clk_p),
        .TMDS_Clk_n      (TMDS_Clk_n),
        .TMDS_Data_p     (TMDS_Data_p),
        .TMDS_Data_n     (TMDS_Data_n)
    );

    // =========================================================================
    // Edge System
    // =========================================================================
    Edge_System #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TH_HIGH   (EDGE_TH_HIGH),
        .TH_LOW    (EDGE_TH_LOW)
    ) U_Edge_System (
        .clk             (clk),
        .reset           (reset),
        .edge_input_sel  (edge_input_sel),
        // Trigger
        .start_edge_trig (start_edge_trig),
        .edge_done       (edge_done),
        .processing      (processing),
        // Capture FB read
        .capture_fb_re   (capture_fb_re_edge),
        .capture_fb_rAddr(capture_fb_rAddr_edge),
        .capture_fb_rData(capture_fb_rData_edge),
        // PC Image FB read
        .pc_img_fb_re    (pc_img_fb_re),
        .pc_img_fb_rAddr (pc_img_fb_rAddr),
        .pc_img_fb_rData (pc_img_fb_rData),
        // Edge FB read
        .edge_fb_re      (edge_fb_re),
        .edge_fb_rAddr   (edge_fb_rAddr),
        .edge_fb_rData   (edge_fb_rData)
    );

    // =========================================================================
    // UART System
    // =========================================================================
    UART_System #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CLK_FREQ  (CLK_FREQ),
        .BAUDRATE  (BAUDRATE),
        .SAMPLING  (SAMPLING),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) U_UART_System (
        .clk            (clk),
        .reset          (reset),
        // UART interface
        .rx             (rx),
        .tx             (tx),
        // Edge FB read
        .edge_fb_re     (edge_fb_re),
        .edge_fb_rAddr  (edge_fb_rAddr),
        .edge_fb_rData  (edge_fb_rData),
        // PC Image FB write
        .pc_img_fb_we   (pc_img_fb_we),
        .pc_img_fb_wAddr(pc_img_fb_wAddr),
        .pc_img_fb_wData(pc_img_fb_wData),
        // Command & Mode Control
        .start_edge_trig(start_edge_trig),
        .edge_input_sel (edge_input_sel),
        // Control & Status
        .edge_tx_trig   (edge_tx_trig),
        .sending        (sending),
        .receiving      (receiving)
    );

endmodule
