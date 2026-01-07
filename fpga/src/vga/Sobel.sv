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
    input  logic [WIDTH-1:0] i_r_data,
    input  logic [WIDTH-1:0] i_g_data,
    input  logic [WIDTH-1:0] i_b_data,
    output logic             o_vsync,
    output logic             o_hsync,
    output logic             o_de,
    output logic [WIDTH-1:0] o_r_data,
    output logic [WIDTH-1:0] o_g_data,
    output logic [WIDTH-1:0] o_b_data
);

    //==========================================================================
    // 1. 내부 변수 및 라인 버퍼 (Gaussian과 동일)
    //==========================================================================
    logic [WIDTH-1:0] lb_r0 [0:H_RES-1]; logic [WIDTH-1:0] lb_r1 [0:H_RES-1];
    logic [WIDTH-1:0] lb_g0 [0:H_RES-1]; logic [WIDTH-1:0] lb_g1 [0:H_RES-1];
    logic [WIDTH-1:0] lb_b0 [0:H_RES-1]; logic [WIDTH-1:0] lb_b1 [0:H_RES-1];

    logic [$clog2(H_RES)-1:0] wr_ptr;

    // 3x3 Window Registers
    logic [WIDTH-1:0] r_p11, r_p12, r_p13, r_p21, r_p22, r_p23, r_p31, r_p32, r_p33;
    logic [WIDTH-1:0] g_p11, g_p12, g_p13, g_p21, g_p22, g_p23, g_p31, g_p32, g_p33;
    logic [WIDTH-1:0] b_p11, b_p12, b_p13, b_p21, b_p22, b_p23, b_p31, b_p32, b_p33;

    //==========================================================================
    // 2. Sobel 연산용 변수 (변경됨)
    //==========================================================================
    // Gx, Gy 결과는 음수가 될 수 있으므로 signed 선언이 중요합니다.
    // 비트 폭: Input(10) + 커널가중치합(4) + Sign(1) = 15 bit 정도 여유 필요
    logic signed [WIDTH+4:0] gx_r, gy_r, gx_g, gy_g, gx_b, gy_b;
    logic [WIDTH+4:0] abs_gx_r, abs_gy_r, abs_gx_g, abs_gy_g, abs_gx_b, abs_gy_b;
    logic [WIDTH+4:0] sum_r, sum_g, sum_b;

    // Sync 지연용 (Sobel은 3클럭 지연)
    logic [2:0] vsync_d, hsync_d, de_d;

    //==========================================================================
    // 3. 라인 버퍼 및 윈도우 구성 (Gaussian과 동일)
    //==========================================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= 0;
            {r_p11, r_p12, r_p13, r_p21, r_p22, r_p23, r_p31, r_p32, r_p33} <= 0;
            {g_p11, g_p12, g_p13, g_p21, g_p22, g_p23, g_p31, g_p32, g_p33} <= 0;
            {b_p11, b_p12, b_p13, b_p21, b_p22, b_p23, b_p31, b_p32, b_p33} <= 0;
        end else if (i_de) begin
            // Buffer Write/Read
            lb_r0[wr_ptr] <= i_r_data; lb_r1[wr_ptr] <= lb_r0[wr_ptr];
            lb_g0[wr_ptr] <= i_g_data; lb_g1[wr_ptr] <= lb_g0[wr_ptr];
            lb_b0[wr_ptr] <= i_b_data; lb_b1[wr_ptr] <= lb_b0[wr_ptr];

            if (wr_ptr == H_RES - 1) wr_ptr <= 0;
            else wr_ptr <= wr_ptr + 1;

            // Window Shift
            r_p13 <= lb_r1[wr_ptr]; r_p12 <= r_p13; r_p11 <= r_p12;
            r_p23 <= lb_r0[wr_ptr]; r_p22 <= r_p23; r_p21 <= r_p22;
            r_p33 <= i_r_data;      r_p32 <= r_p33; r_p31 <= r_p32;
            
            g_p13 <= lb_g1[wr_ptr]; g_p12 <= g_p13; g_p11 <= g_p12;
            g_p23 <= lb_g0[wr_ptr]; g_p22 <= g_p23; g_p21 <= g_p22;
            g_p33 <= i_g_data;      g_p32 <= g_p33; g_p31 <= g_p32;

            b_p13 <= lb_b1[wr_ptr]; b_p12 <= b_p13; b_p11 <= b_p12;
            b_p23 <= lb_b0[wr_ptr]; b_p22 <= b_p23; b_p21 <= b_p22;
            b_p33 <= i_b_data;      b_p32 <= b_p33; b_p31 <= b_p32;
        end
    end

    //==========================================================================
    // 4. Sobel Arithmetic Pipeline
    //==========================================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            gx_r <= 0; gy_r <= 0; sum_r <= 0; o_r_data <= 0;
            gx_g <= 0; gy_g <= 0; sum_g <= 0; o_g_data <= 0;
            gx_b <= 0; gy_b <= 0; sum_b <= 0; o_b_data <= 0;
        end else if (i_de) begin
            //--------------------------------------------------------------
            // Stage 1: Gx, Gy 계산 (Signed 연산)
            //--------------------------------------------------------------
            // Gx Kernel: [-1 0 1], [-2 0 2], [-1 0 1] -> (Right - Left)
            // Gy Kernel: [ 1 2 1], [ 0 0 0], [-1 -2 -1] -> (Top - Bottom)
            // 'signed' 캐스팅을 통해 음수 계산이 정상적으로 되도록 함
            
            // Red
            gx_r <= $signed({1'b0, r_p13}) + $signed({1'b0, r_p23} << 1) + $signed({1'b0, r_p33}) -
                    ($signed({1'b0, r_p11}) + $signed({1'b0, r_p21} << 1) + $signed({1'b0, r_p31}));
            gy_r <= $signed({1'b0, r_p11}) + $signed({1'b0, r_p12} << 1) + $signed({1'b0, r_p13}) -
                    ($signed({1'b0, r_p31}) + $signed({1'b0, r_p32} << 1) + $signed({1'b0, r_p33}));
            
            // Green
            gx_g <= $signed({1'b0, g_p13}) + $signed({1'b0, g_p23} << 1) + $signed({1'b0, g_p33}) -
                    ($signed({1'b0, g_p11}) + $signed({1'b0, g_p21} << 1) + $signed({1'b0, g_p31}));
            gy_g <= $signed({1'b0, g_p11}) + $signed({1'b0, g_p12} << 1) + $signed({1'b0, g_p13}) -
                    ($signed({1'b0, g_p31}) + $signed({1'b0, g_p32} << 1) + $signed({1'b0, g_p33}));
            
            // Blue
            gx_b <= $signed({1'b0, b_p13}) + $signed({1'b0, b_p23} << 1) + $signed({1'b0, b_p33}) -
                    ($signed({1'b0, b_p11}) + $signed({1'b0, b_p21} << 1) + $signed({1'b0, b_p31}));
            gy_b <= $signed({1'b0, b_p11}) + $signed({1'b0, b_p12} << 1) + $signed({1'b0, b_p13}) -
                    ($signed({1'b0, b_p31}) + $signed({1'b0, b_p32} << 1) + $signed({1'b0, b_p33}));

            //--------------------------------------------------------------
            // Stage 2: 절댓값 계산 및 합산 (|Gx| + |Gy|)
            //--------------------------------------------------------------
            abs_gx_r = (gx_r[WIDTH+4]) ? -gx_r : gx_r; // MSB가 1(음수)이면 반전
            abs_gy_r = (gy_r[WIDTH+4]) ? -gy_r : gy_r;
            sum_r    <= abs_gx_r + abs_gy_r;

            abs_gx_g = (gx_g[WIDTH+4]) ? -gx_g : gx_g;
            abs_gy_g = (gy_g[WIDTH+4]) ? -gy_g : gy_g;
            sum_g    <= abs_gx_g + abs_gy_g;

            abs_gx_b = (gx_b[WIDTH+4]) ? -gx_b : gx_b;
            abs_gy_b = (gy_b[WIDTH+4]) ? -gy_b : gy_b;
            sum_b    <= abs_gx_b + abs_gy_b;

            //--------------------------------------------------------------
            // Stage 3: Saturation (Overflow 방지) 및 출력
            //--------------------------------------------------------------
            // 결과가 최대값(1023 등)을 넘으면 최대값으로 자름 (Clamp)
            if (sum_r > {WIDTH{1'b1}}) o_r_data <= {WIDTH{1'b1}};
            else                       o_r_data <= sum_r[WIDTH-1:0];

            if (sum_g > {WIDTH{1'b1}}) o_g_data <= {WIDTH{1'b1}};
            else                       o_g_data <= sum_g[WIDTH-1:0];

            if (sum_b > {WIDTH{1'b1}}) o_b_data <= {WIDTH{1'b1}};
            else                       o_b_data <= sum_b[WIDTH-1:0];
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
