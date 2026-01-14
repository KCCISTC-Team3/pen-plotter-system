`timescale 1ns / 1ps

module Gaussian_Blur #(
    parameter WIDTH = 8,
    parameter H_RES = 80
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
    // 1. 내부 변수 선언
    //==========================================================================
    
    // 라인 버퍼 (Line Buffer)
    // FPGA 내부 메모리(BRAM)로 합성되도록 유도
    logic [WIDTH-1:0] lb_0 [0:H_RES-1]; logic [WIDTH-1:0] lb_1 [0:H_RES-1];

    // 버퍼 제어용 포인터
    logic [$clog2(H_RES)-1:0] wr_ptr;

    // 3x3 윈도우 픽셀 레지스터
    // p11 p12 p13 (Top)
    // p21 p22 p23 (Mid)
    // p31 p32 p33 (Bot - Current)
    logic [WIDTH-1:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;

    // 연산 결과 저장용 (Sum) - 오버플로우 방지를 위해 비트 확장
    logic [WIDTH+3:0] sum;
    
    // 신호 지연(Delay)을 위한 레지스터 (Sync 맞춤용)
    logic [1:0] vsync_d, hsync_d, de_d;

    //==========================================================================
    // 2. 라인 버퍼 및 윈도우 구성 (Pixel Pipeline)
    //==========================================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= 0;
            {p11, p12, p13, p21, p22, p23, p31, p32, p33} <= 0;
        end else if (i_de) begin
            lb_0[wr_ptr] <= i_data;
            lb_1[wr_ptr] <= lb_0[wr_ptr];

            // 포인터 업데이트
            if (wr_ptr == H_RES - 1) wr_ptr <= 0;
            else wr_ptr <= wr_ptr + 1;

            // 2-2. 3x3 윈도우 시프트 (Window Sliding)
            p13 <= lb_1[wr_ptr]; p12 <= p13; p11 <= p12;
            p23 <= lb_0[wr_ptr]; p22 <= p23; p21 <= p22;
            p33 <= i_data;       p32 <= p33; p31 <= p32;
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
            sum     <= 0;
            o_data  <= 0;
        end else if (i_de) begin // 데이터가 유효할 때만 연산 갱신
            // Stage 1: 가중치 합 계산 (Shift 연산으로 최적화)
            sum <= (p11) + (p12 << 1) + (p13) +
                   (p21 << 1) + (p22 << 2) + (p23 << 1) +
                   (p31) + (p32 << 1) + (p33);

            // Stage 2: 나누기 16 (Shift Right 4) 및 출력
            // sum 계산이 한 클럭 걸렸으므로, 다음 클럭에 출력
            o_data <= sum[WIDTH+3:4];
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