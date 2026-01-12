`timescale 1ns / 1ps

module Canny #(
    parameter WIDTH   = 8,
    parameter H_RES   = 80,       // 가로 해상도
    parameter TH_HIGH = 240,       // Strong Edge 기준
    parameter TH_LOW  = 120        // Weak Edge 기준
)(
    input  logic             clk,
    input  logic             rstn,
    input  logic             i_vsync,
    input  logic             i_hsync,
    input  logic             i_de,
    input  logic [WIDTH-1:0] i_data, // [Input] Grayscale Pixel Data
    output logic             o_vsync,
    output logic             o_hsync,
    output logic             o_de,
    output logic [WIDTH-1:0] o_data
);

    //==========================================================================
    // STAGE 1: Pixel Line Buffering (For Sobel 3x3)
    //==========================================================================
    logic [WIDTH-1:0] lb1_row0 [0:H_RES-1];
    logic [WIDTH-1:0] lb1_row1 [0:H_RES-1];
    
    logic [WIDTH-1:0] s1_p11, s1_p12, s1_p13;
    logic [WIDTH-1:0] s1_p21, s1_p22, s1_p23;
    logic [WIDTH-1:0] s1_p31, s1_p32, s1_p33;
    
    logic [9:0] col_cnt1;
    logic       s1_valid; // Pipeline Valid Signal

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            col_cnt1 <= 0;
            s1_valid <= 0;
        end else if (i_de) begin
            // 1. Line Buffer Write/Shift
            lb1_row0[col_cnt1] <= i_data;       // Current Line -> Row 0 (logic reversal for simplicity)
            lb1_row1[col_cnt1] <= lb1_row0[col_cnt1]; // Row 0 -> Row 1
            
            // 2. Window Shift (3x3)
            // Row 0 (Top - Oldest)
            s1_p13 <= lb1_row1[col_cnt1]; s1_p12 <= s1_p13; s1_p11 <= s1_p12;
            // Row 1 (Middle)
            s1_p23 <= lb1_row0[col_cnt1]; s1_p22 <= s1_p23; s1_p21 <= s1_p22;
            // Row 2 (Bottom - Current Input)
            s1_p33 <= i_data;             s1_p32 <= s1_p33; s1_p31 <= s1_p32;

            // 3. Control
            if (col_cnt1 == H_RES-1) col_cnt1 <= 0;
            else col_cnt1 <= col_cnt1 + 1;
            
            s1_valid <= 1'b1; // (Warm-up 무시하고 흐름 제어용)
        end else begin
            s1_valid <= 1'b0;
        end
    end

    //==========================================================================
    // STAGE 2: Gradient Calculation (Sobel) & Direction
    //==========================================================================
    logic signed [10:0] gx, gy;
    logic [10:0] abs_gx, abs_gy;
    logic [WIDTH-1:0] mag_val; // Magnitude (Clamped to 8bit)
    logic [1:0]       dir_val; // Direction (0,1,2,3)
    logic             s2_valid;

    always_ff @(posedge clk) begin
        if (s1_valid) begin
            // 1. Sobel Operator
            // Gx: Right - Left
            gx <= (s1_p13 + (s1_p23 << 1) + s1_p33) - (s1_p11 + (s1_p21 << 1) + s1_p31);
            // Gy: Bottom - Top
            gy <= (s1_p31 + (s1_p32 << 1) + s1_p33) - (s1_p11 + (s1_p12 << 1) + s1_p13);
            
            s2_valid <= 1'b1;
        end else begin
            s2_valid <= 1'b0;
        end
    end

    // Combinational Logic for Abs, Mag, Dir (Next Cycle Logic)
    logic [10:0] c_abs_gx, c_abs_gy;
    logic [11:0] c_sum_mag;
    logic [1:0]  c_dir;

    always_comb begin
        c_abs_gx = (gx[10]) ? (~gx + 1) : gx;
        c_abs_gy = (gy[10]) ? (~gy + 1) : gy;
        c_sum_mag = c_abs_gx + c_abs_gy; // Approx Magnitude

        // Direction Quantization (FPGA Friendly)
        // 0: Vertical Edge (Horz Gradient)
        // 1: 45 Deg Edge
        // 2: Horizontal Edge (Vert Gradient)
        // 3: 135 Deg Edge
        
        // Using simplified comparison instead of tan()
        if (c_abs_gx > (c_abs_gy << 1)) begin       // |Gx| > 2*|Gy| (Slope < 0.5)
            c_dir = 2'd0; // Vertical Edge
        end else if (c_abs_gy > (c_abs_gx << 1)) begin // |Gy| > 2*|Gx| (Slope > 2)
            c_dir = 2'd2; // Horizontal Edge
        end else begin
            // Diagonal: Check Signs (Assuming Y grows down)
            // Gx, Gy same sign -> Gradient is TopLeft-to-BotRight (\) -> Edge is (/)
            if ((gx[10] == gy[10])) 
                c_dir = 2'd3; // 135 Deg Gradient -> 45 Deg Edge (Depends on Convention)
            else 
                c_dir = 2'd1; // 45 Deg Gradient -> 135 Deg Edge
        end
    end

    // Pipeline Register for Sobel Result
    always_ff @(posedge clk) begin
        if (s2_valid) begin
            // [튜닝] 감도 1/2로 줄이기 ( >> 1 추가)
            // 원래 값보다 절반으로 줄어들어서, 훨씬 큰 변화가 있어야만 검출됨
            mag_val <= ((c_sum_mag >> 1) > 255) ? 8'hFF : c_sum_mag[8:1]; 
            dir_val <= c_dir;
        end
    end

    //==========================================================================
    // STAGE 3: Magnitude Line Buffering (For NMS 3x3)
    //==========================================================================
    // NMS를 수행하려면 계산된 Magnitude를 다시 3x3으로 묶어야 함
    logic [WIDTH-1:0] lb2_row0 [0:H_RES-1];
    logic [WIDTH-1:0] lb2_row1 [0:H_RES-1];
    logic [1:0]       lb2_dir  [0:H_RES-1]; // Center Direction 저장용

    logic [WIDTH-1:0] m11, m12, m13;
    logic [WIDTH-1:0] m21, m22, m23;
    logic [WIDTH-1:0] m31, m32, m33;
    logic [1:0]       center_dir;
    
    logic [9:0] col_cnt2;
    logic       s3_valid; // NMS Window Ready

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            col_cnt2 <= 0;
            s3_valid <= 0;
        end else if (s2_valid) begin // Sobel 결과가 유효할 때 동작
            // 1. Line Buffer (Magnitude)
            lb2_row0[col_cnt2] <= mag_val;
            lb2_row1[col_cnt2] <= lb2_row0[col_cnt2];
            
            // 2. Line Buffer (Direction - Only need Center Row later)
            lb2_dir[col_cnt2]  <= dir_val;

            // 3. Window Construction
            m13 <= lb2_row1[col_cnt2]; m12 <= m13; m11 <= m12;
            m23 <= lb2_row0[col_cnt2]; m22 <= m23; m21 <= m22;
            m33 <= mag_val;            m32 <= m33; m31 <= m32;

            // Center Direction (Sync with m22)
            center_dir <= lb2_dir[col_cnt2];

            // 4. Control
            if (col_cnt2 == H_RES-1) col_cnt2 <= 0;
            else col_cnt2 <= col_cnt2 + 1;

            s3_valid <= 1'b1;
        end else begin
            s3_valid <= 1'b0;
        end
    end

    //==========================================================================
    // STAGE 4: Non-Maximum Suppression (NMS) Logic
    //==========================================================================
    logic [WIDTH-1:0] nms_pixel;
    
    always_comb begin
        nms_pixel = 8'd0;
        // m22 (Center)가 방향축의 이웃보다 크거나 같으면 유지, 아니면 0
        case (center_dir)
            2'd0: begin // Vertical Edge (좌우 Gradient? No, Direction Logic에 따름)
                  // 위 Logic에서 0은 Vertical Edge -> 좌우 픽셀 비교
                  if (m22 >= m21 && m22 >= m23) nms_pixel = m22;
            end
            2'd1: begin // Diagonal (Top-Right / Bot-Left)
                  if (m22 >= m13 && m22 >= m31) nms_pixel = m22;
            end
            2'd2: begin // Horizontal Edge -> 상하 픽셀 비교
                  if (m22 >= m12 && m22 >= m32) nms_pixel = m22;
            end
            2'd3: begin // Diagonal (Top-Left / Bot-Right)
                  if (m22 >= m11 && m22 >= m33) nms_pixel = m22;
            end
            default: nms_pixel = 0;
        endcase
    end

    //==========================================================================
    // STAGE 5: Hysteresis Thresholding & Final Output
    //==========================================================================
    logic [WIDTH-1:0] final_out;

    always_ff @(posedge clk) begin
        if (s3_valid) begin
            // [튜닝] 엄청 빡빡한 기준: TH_HIGH를 넘지 못하면 가차 없이 0 처리
            if (nms_pixel >= TH_HIGH)
                final_out <= 8'hFF; // 확실한 엣지만 흰색
            else
                final_out <= 8'h00; // 애매한 건 전부 검은색 (노이즈 박멸)
        end else begin
            final_out <= 8'h00;
        end
    end

    //==========================================================================
    // SYNC DELAY (Compensate for Latency)
    //==========================================================================
    // Total Latency: 
    // Stage 1 (Window) + Stage 2 (Calc) + Stage 3 (Window) + Stage 4/5 (Calc)
    // Approx: 1 Line + 1 Line = 2 Lines + @ Clocks
    // 안전하게 Circular Buffer로 Sync 신호를 지연시킵니다.
    
    localparam DELAY_DEPTH = (H_RES * 2) + 10; // 2줄 + 여유분
    logic [2:0] sync_buf [0:DELAY_DEPTH];
    logic [12:0] wr_ptr, rd_ptr; // 포인터 크기 증가

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wr_ptr <= DELAY_DEPTH - 5; // Read보다 앞서서 시작 (Fill Buffer)
            rd_ptr <= 0;
            o_vsync <= 0; o_hsync <= 0; o_de <= 0;
        end else begin
            // Write Current Sync
            sync_buf[wr_ptr] <= {i_vsync, i_hsync, i_de};
            
            // Read Delayed Sync
            {o_vsync, o_hsync, o_de} <= sync_buf[rd_ptr];

            // Pointer Update
            if (wr_ptr == DELAY_DEPTH) wr_ptr <= 0;
            else wr_ptr <= wr_ptr + 1;

            if (rd_ptr == DELAY_DEPTH) rd_ptr <= 0;
            else rd_ptr <= rd_ptr + 1;
        end
    end

    // Final Assignment
    assign o_data = final_out;

endmodule