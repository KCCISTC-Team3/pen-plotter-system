`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 16:45:53
// Design Name: 
// Module Name: Gaussian
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


module Gaussian #(
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
    // 1. 내부 변수 선언
    //==========================================================================
    
    // 라인 버퍼 (Line Buffer) - R, G, B 각각 2줄씩 필요
    // FPGA 내부 메모리(BRAM)로 합성되도록 유도
    logic [WIDTH-1:0] lb_r0 [0:H_RES-1]; logic [WIDTH-1:0] lb_r1 [0:H_RES-1];
    logic [WIDTH-1:0] lb_g0 [0:H_RES-1]; logic [WIDTH-1:0] lb_g1 [0:H_RES-1];
    logic [WIDTH-1:0] lb_b0 [0:H_RES-1]; logic [WIDTH-1:0] lb_b1 [0:H_RES-1];

    // 버퍼 제어용 포인터
    logic [$clog2(H_RES)-1:0] wr_ptr;

    // 3x3 윈도우 픽셀 레지스터 (R, G, B)
    // p11 p12 p13 (Top)
    // p21 p22 p23 (Mid)
    // p31 p32 p33 (Bot - Current)
    logic [WIDTH-1:0] r_p11, r_p12, r_p13, r_p21, r_p22, r_p23, r_p31, r_p32, r_p33;
    logic [WIDTH-1:0] g_p11, g_p12, g_p13, g_p21, g_p22, g_p23, g_p31, g_p32, g_p33;
    logic [WIDTH-1:0] b_p11, b_p12, b_p13, b_p21, b_p22, b_p23, b_p31, b_p32, b_p33;

    // 연산 결과 저장용 (Sum) - 오버플로우 방지를 위해 비트 확장
    logic [WIDTH+3:0] sum_r, sum_g, sum_b;
    
    // 신호 지연(Delay)을 위한 레지스터 (Sync 맞춤용)
    logic [1:0] vsync_d, hsync_d, de_d;

    //==========================================================================
    // 2. 라인 버퍼 및 윈도우 구성 (Pixel Pipeline)
    //==========================================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= 0;
            {r_p11, r_p12, r_p13, r_p21, r_p22, r_p23, r_p31, r_p32, r_p33} <= 0;
            {g_p11, g_p12, g_p13, g_p21, g_p22, g_p23, g_p31, g_p32, g_p33} <= 0;
            {b_p11, b_p12, b_p13, b_p21, b_p22, b_p23, b_p31, b_p32, b_p33} <= 0;
        end else if (i_de) begin
            lb_r0[wr_ptr] <= i_r_data;
            lb_r1[wr_ptr] <= lb_r0[wr_ptr];
            lb_g0[wr_ptr] <= i_g_data;
            lb_g1[wr_ptr] <= lb_g0[wr_ptr];
            lb_b0[wr_ptr] <= i_b_data;
            lb_b1[wr_ptr] <= lb_b0[wr_ptr];

            // 포인터 업데이트
            if (wr_ptr == H_RES - 1) wr_ptr <= 0;
            else wr_ptr <= wr_ptr + 1;

            // 2-2. 3x3 윈도우 시프트 (Window Sliding)
            // Red
            r_p13 <= lb_r1[wr_ptr]; r_p12 <= r_p13; r_p11 <= r_p12;
            r_p23 <= lb_r0[wr_ptr]; r_p22 <= r_p23; r_p21 <= r_p22;
            r_p33 <= i_r_data;      r_p32 <= r_p33; r_p31 <= r_p32;
            
            // Green
            g_p13 <= lb_g1[wr_ptr]; g_p12 <= g_p13; g_p11 <= g_p12;
            g_p23 <= lb_g0[wr_ptr]; g_p22 <= g_p23; g_p21 <= g_p22;
            g_p33 <= i_g_data;      g_p32 <= g_p33; g_p31 <= g_p32;

            // Blue
            b_p13 <= lb_b1[wr_ptr]; b_p12 <= b_p13; b_p11 <= b_p12;
            b_p23 <= lb_b0[wr_ptr]; b_p22 <= b_p23; b_p21 <= b_p22;
            b_p33 <= i_b_data;      b_p32 <= b_p33; b_p31 <= b_p32;
        end
    end

    //==========================================================================
    // 3. 컨볼루션 연산 (Arithmetic Pipeline)
    //==========================================================================
    // Kernel:
    // 1 2 1
    // 2 4 2
    // 1 2 1  -> Sum total 16 (Divide by 16 using >> 4)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            sum_r <= 0; sum_g <= 0; sum_b <= 0;
            o_r_data <= 0; o_g_data <= 0; o_b_data <= 0;
        end else if (i_de) begin // 데이터가 유효할 때만 연산 갱신
            // Stage 1: 가중치 합 계산 (Shift 연산으로 최적화)
            sum_r <= (r_p11) + (r_p12 << 1) + (r_p13) +
                     (r_p21 << 1) + (r_p22 << 2) + (r_p23 << 1) +
                     (r_p31) + (r_p32 << 1) + (r_p33);

            sum_g <= (g_p11) + (g_p12 << 1) + (g_p13) +
                     (g_p21 << 1) + (g_p22 << 2) + (g_p23 << 1) +
                     (g_p31) + (g_p32 << 1) + (g_p33);

            sum_b <= (b_p11) + (b_p12 << 1) + (b_p13) +
                     (b_p21 << 1) + (b_p22 << 2) + (b_p23 << 1) +
                     (b_p31) + (b_p32 << 1) + (b_p33);
                     
            // Stage 2: 나누기 16 (Shift Right 4) 및 출력
            // sum 계산이 한 클럭 걸렸으므로, 다음 클럭에 출력
            o_r_data <= sum_r[WIDTH+3:4];
            o_g_data <= sum_g[WIDTH+3:4];
            o_b_data <= sum_b[WIDTH+3:4];
        end
    end

    //==========================================================================
    // 4. Sync 신호 지연 (Delay Matching)
    //==========================================================================
    // 연산 파이프라인 지연 시간: 2 클럭 (Sum 계산 1클럭 + 출력 레지스터 1클럭)
    // 데이터 흐름과 동기화 신호를 맞추기 위해 Shift Register 사용
    
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vsync_d <= 0; hsync_d <= 0; de_d <= 0;
            o_vsync <= 0; o_hsync <= 0; o_de <= 0;
        end else begin
            // 2 Cycle Delay
            vsync_d <= {vsync_d[0], i_vsync};
            hsync_d <= {hsync_d[0], i_hsync};
            de_d    <= {de_d[0],    i_de};

            // 최종 출력 연결
            o_vsync <= vsync_d[1];
            o_hsync <= hsync_d[1];
            o_de    <= de_d[1];
        end
    end

endmodule