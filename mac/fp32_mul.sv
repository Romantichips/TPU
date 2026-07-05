`timescale 1ns / 1ps

module FP32multiply (
    input               clk,
    input       [31:0]  floatA,
    input       [31:0]  floatB,
    output reg  [31:0]  product
);
    // First stage register
    reg       stage1_valid;
    reg       stage1_sign;
    reg [8:0] stage1_exponent;
    reg [7:0] multA_1;
    reg [7:0] multA_2;
    reg [7:0] multA_3;
    reg [7:0] multB_1;
    reg [7:0] multB_2;
    reg [7:0] multB_3;
    always@(posedge clk)begin
        stage1_valid <= (floatA != 0) && (floatB != 0);
        stage1_sign <= floatA[31] ^ floatB[31];
        stage1_exponent <= floatA[30:23] + floatB[30:23] - 9'd127;
        multA_1 <= {1'b1, floatA[22:16]};
        multA_2 <= floatA[15:8];
        multA_3 <= floatA[7:0];
        multB_1 <= {1'b1, floatB[22:16]};
        multB_2 <= floatB[15:8];
        multB_3 <= floatB[7:0];
    end
    // Second stage register
    reg        stage2_valid;
    reg        stage2_sign;
    reg [8:0]  stage2_exponent;
    reg [15:0] stage2_fraction_1;
    reg [15:0] stage2_fraction_2;
    reg [15:0] stage2_fraction_3;
    reg [15:0] stage2_fraction_4;
    reg [15:0] stage2_fraction_5;
    reg [15:0] stage2_fraction_6;
    reg [15:0] stage2_fraction_7;
    reg [15:0] stage2_fraction_8;
    reg [15:0] stage2_fraction_9;
    always @(posedge clk) begin 
        stage2_valid <= stage1_valid;
        stage2_sign <= stage1_sign;
        stage2_exponent <= stage1_exponent;
        stage2_fraction_1 <= (multA_1 * multB_1);
        stage2_fraction_2 <= (multA_1 * multB_2);
        stage2_fraction_3 <= (multA_1 * multB_3);
        stage2_fraction_4 <= (multA_2 * multB_1);
        stage2_fraction_5 <= (multA_2 * multB_2);
        stage2_fraction_6 <= (multA_2 * multB_3);
        stage2_fraction_7 <= (multA_3 * multB_1);
        stage2_fraction_8 <= (multA_3 * multB_2);
        stage2_fraction_9 <= (multA_3 * multB_3);
    end
    // Third stage register
    reg        stage3_valid;
    reg        stage3_sign;
    reg [8:0]  stage3_exponent;
    reg [47:0] stage3_fraction;
    always @(posedge clk) begin
        stage3_valid <= stage2_valid;
        stage3_sign <= stage2_sign;
        stage3_exponent <= stage2_exponent;
        stage3_fraction <= (stage2_fraction_1 << 32) + (stage2_fraction_2 << 24) + (stage2_fraction_3 << 16) + (stage2_fraction_4 << 24) + (stage2_fraction_5 << 16) + (stage2_fraction_6 <<8) + (stage2_fraction_7 << 16) + (stage2_fraction_8 << 8) + (stage2_fraction_9);  
    end
    // Fourth stage register
    reg [8:0]  stage4_exponent;
    reg [22:0] stage4_mantissa;
    reg        stage4_sign;
    reg        stage4_valid;
    always@(posedge clk)begin
         stage4_exponent <= (stage3_fraction[47] == 1'b1) ? stage3_exponent + 8'd1 : stage3_exponent;
         stage4_mantissa <= (stage3_fraction[47] == 1'b1) ? stage3_fraction[46:24] : stage3_fraction[45:23];
         stage4_sign <= stage3_sign;
         stage4_valid <= stage3_valid;
    end
    // Final output
    always @(posedge clk ) begin
        if (!stage4_valid) begin
            product <= 32'b0;
        end else begin
            product <= {stage4_sign, stage4_exponent[7:0], stage4_mantissa};
        end
    end
endmodule