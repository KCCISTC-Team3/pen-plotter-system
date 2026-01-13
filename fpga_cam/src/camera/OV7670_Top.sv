module OV7670_Top #(
    parameter DATA_WIDTH  = 8,
    parameter RGB_WIDTH   = 16,
    parameter IMG_WIDTH   = 320,
    parameter IMG_HEIGHT  = 240,
    parameter CROP_WIDTH  = 176,
    parameter CROP_HEIGHT = 240,
    parameter ADDR_WIDTH  = $clog2(CROP_WIDTH * CROP_HEIGHT)
) (
    input  logic                  clk,
    input  logic                  reset,
    output tri                    SCL,
    inout  tri                    SDA,
    input  logic                  pclk,
    input  logic                  href,
    input  logic                  vsync,
    input  logic [DATA_WIDTH-1:0] data,
    output logic                  we,
    output logic [ADDR_WIDTH-1:0] wAddr,
    output logic [ RGB_WIDTH-1:0] wData
);

    SCCB_Interface U_SCCB_Intf (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA)
    );

    OV7670_Capture #(
        .DATA_WIDTH (DATA_WIDTH),
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .CROP_WIDTH (CROP_WIDTH),
        .CROP_HEIGHT(CROP_HEIGHT)
    ) U_OV7670_Mem_Ctrl (
        .pclk (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );

endmodule
