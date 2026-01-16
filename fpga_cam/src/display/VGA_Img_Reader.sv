module VGA_Img_Reader #(
    parameter DATA_WIDTH = 8,
    parameter RGB_WIDTH = 16,
    parameter IMG_WIDTH = 176,
    parameter IMG_HEIGHT = 240,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT),
    parameter POSITION_X = 0  // 0: Left (0~319), 1: Right (320~639)
) (
    input  logic                  clk,
    input  logic                  DE,
    input  logic [           9:0] x_pixel,
    input  logic [           9:0] y_pixel,
    output logic [ADDR_WIDTH-1:0] addr,
    input  logic [ RGB_WIDTH-1:0] imgData,
    output logic [DATA_WIDTH-1:0] r_port,
    output logic [DATA_WIDTH-1:0] g_port,
    output logic [DATA_WIDTH-1:0] b_port
);
    localparam X_START_BASE = POSITION_X ? 320 : 0;
    localparam CENTER_X = X_START_BASE + ((320 - IMG_WIDTH) >> 1);
    localparam CENTER_Y = (480 - IMG_HEIGHT) >> 1;

    logic display_en, display_en_reg, display_en_reg2;
    logic [ADDR_WIDTH-1:0] addr_comb, addr_reg;
    logic in_region;

    assign in_region = (x_pixel >= CENTER_X) && (x_pixel < CENTER_X + IMG_WIDTH) &&
                       (y_pixel >= CENTER_Y) && (y_pixel < CENTER_Y + IMG_HEIGHT);

    assign display_en = DE && in_region;

    assign addr_comb = in_region ? 
                       ((y_pixel - CENTER_Y) * IMG_WIDTH + (x_pixel - CENTER_X)) + 1 : 0;

    always_ff @(posedge clk) begin
        if (in_region) begin
            addr_reg <= addr_comb;
        end
        display_en_reg <= display_en;
    end

    always_ff @(posedge clk) begin
        display_en_reg2 <= display_en_reg;
    end

    assign addr = addr_reg;

    assign {r_port, g_port, b_port} = display_en_reg2 ? {imgData[15:12], 4'b0, imgData[10:7], 4'b0, imgData[4:1], 4'b0} : 0;

    // always_comb begin
    //     if (display_en_reg2) begin
    //         r_port = {imgData[15:12], 4'b0};
    //         g_port = {imgData[10:7], 4'b0};
    //         b_port = {imgData[4:1], 4'b0};
    //     end else begin
    //         r_port = 8'h0;
    //         g_port = 8'h0;
    //         b_port = 8'h0;
    //     end
    // end
endmodule
