`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 16:46:34
// Design Name: 
// Module Name: Sobel
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

module Sobel #(
    parameter WIDTH = 8,
    parameter H_RES = 640
)(
    input  logic             clk,
    input  logic             rstn,
    input  logic             i_vsync,
    input  logic             i_hsync,
    input  logic             i_de,
    input  logic [WIDTH-1:0] i_data,
    output logic             o_vsync,
    output logic             o_hsync,
    output logic             o_de,
    output logic [WIDTH-1:0] o_data
);

    //==========================================================================
    // 1. 내부 변수 및 라인 버퍼 (Gaussian과 동일)
    //==========================================================================
    logic [WIDTH-1:0] lb_0 [0:H_RES-1]; logic [WIDTH-1:0] lb_1 [0:H_RES-1];

    logic [$clog2(H_RES)-1:0] wr_ptr;

    // 3x3 Window Registers
    logic [WIDTH-1:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;

    //==========================================================================
    // 2. Sobel 연산용 변수 (변경됨)
    //==========================================================================
    // Gx, Gy 결과는 음수가 될 수 있으므로 signed 선언이 중요합니다.
    // 비트 폭: Input(10) + 커널가중치합(4) + Sign(1) = 15 bit 정도 여유 필요
    logic signed [WIDTH+4:0] gx, gy;
    logic [WIDTH+4:0] abs_gx, abs_gy;
    logic [WIDTH+4:0] sum;

    // Sync 지연용 (Sobel은 3클럭 지연)
    logic [2:0] vsync_d, hsync_d, de_d;

    //==========================================================================
    // 3. 라인 버퍼 및 윈도우 구성 (Gaussian과 동일)
    //==========================================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= 0;
            {p11, p12, p13, p21, p22, p23, p31, p32, p33} <= 0;
        end else if (i_de) begin
            // Buffer Write/Read
            lb_0[wr_ptr] <= i_data; lb_1[wr_ptr] <= lb_0[wr_ptr];

            if (wr_ptr == H_RES - 1) wr_ptr <= 0;
            else wr_ptr <= wr_ptr + 1;

            // Window Shift
            p13 <= lb_1[wr_ptr]; p12 <= p13; p11 <= p12;
            p23 <= lb_0[wr_ptr]; p22 <= p23; p21 <= p22;
            p33 <= i_data;       p32 <= p33; p31 <= p32;
        end
    end

    //==========================================================================
    // 4. Sobel Arithmetic Pipeline
    //==========================================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            gx <= 0; gy <= 0; sum <= 0; o_data <= 0;
        end else if (i_de) begin
            //--------------------------------------------------------------
            // Stage 1: Gx, Gy 계산 (Signed 연산)
            //--------------------------------------------------------------
            // Gx Kernel: [-1 0 1], [-2 0 2], [-1 0 1] -> (Right - Left)
            // Gy Kernel: [ 1 2 1], [ 0 0 0], [-1 -2 -1] -> (Top - Bottom)
            // 'signed' 캐스팅을 통해 음수 계산이 정상적으로 되도록 함
            gx <= $signed({1'b0, p13}) + $signed({1'b0, p23} << 1) + $signed({1'b0, p33}) -
                    ($signed({1'b0, p11}) + $signed({1'b0, p21} << 1) + $signed({1'b0, p31}));
            gy <= $signed({1'b0, p11}) + $signed({1'b0, p12} << 1) + $signed({1'b0, p13}) -
                    ($signed({1'b0, p31}) + $signed({1'b0, p32} << 1) + $signed({1'b0, p33}));

            //--------------------------------------------------------------
            // Stage 2: 절댓값 계산 및 합산 (|Gx| + |Gy|)
            //--------------------------------------------------------------
            abs_gx <= (gx[WIDTH+4]) ? -gx : gx; // MSB가 1(음수)이면 반전
            abs_gy <= (gy[WIDTH+4]) ? -gy : gy;
            sum    <= abs_gx + abs_gy;

            //--------------------------------------------------------------
            // Stage 3: Saturation (Overflow 방지) 및 출력
            //--------------------------------------------------------------
            // 결과가 최대값(1023 등)을 넘으면 최대값으로 자름 (Clamp)
            if (sum > {WIDTH{1'b1}}) o_data <= {WIDTH{1'b1}};
            else                     o_data <= sum[WIDTH-1:0];
        end
    end

    //==========================================================================
    // 5. Sync 신호 지연 (3 Cycle Delay)
    //==========================================================================
    // Arithmetic Stage가 3단계(Calc -> Abs/Sum -> Clamp)이므로 3클럭 지연
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vsync_d <= 0; hsync_d <= 0; de_d <= 0;
            o_vsync <= 0; o_hsync <= 0; o_de <= 0;
        end else begin
            // 3 Cycle Delay Shift Register
            vsync_d <= {vsync_d[1:0], i_vsync};
            hsync_d <= {hsync_d[1:0], i_hsync};
            de_d    <= {de_d[1:0],    i_de};

            o_vsync <= vsync_d[2];
            o_hsync <= hsync_d[2];
            o_de    <= de_d[2];
        end
    end

endmodule
