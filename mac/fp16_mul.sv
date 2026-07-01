`timescale 1ns / 1ps

module FP16multiply (
    input              clk,
    input       [15:0] floatA,
    input       [15:0] floatB,
    output reg  [15:0] product
);
// First-level pipeline register
reg        stage1_zero_flag;
reg        stage1_sign;
reg [5:0]  stage1_exp_raw; 
reg [21:0] stage1_fraction_1;
reg [15:0] stage1_fraction_2;
reg [15:0] stage1_fraction_3;
reg [9:0]  stage1_fraction_4;

always @(posedge clk) begin
    // Zero-input detection
    stage1_zero_flag <= (floatA == 0) || (floatB == 0);
    // Symbol and exponent calculation
    stage1_sign     <= floatA[15] ^ floatB[15] ;
    stage1_exp_raw  <= floatA[14:10] + floatB[14:10] - 6'd15;
    // Last-digit multiplication (implicit pipeline register)
    stage1_fraction_1 <= ({1'b1, floatA[9:5]} * {1'b1, floatB[9:5]}) << 10;
    stage1_fraction_2 <= ({1'b1, floatA[9:5]} * floatB[4:0]) << 5;
    stage1_fraction_3 <= (floatA[4:0] * {1'b1, floatB[9:5]}) << 5;
    stage1_fraction_4 <= floatA[4:0] * floatB[4:0];
end

// Normalization
wire [21:0] stage1_fraction;
wire [5:0]  final_exp;
wire [9:0]  final_mantissa;

assign stage1_fraction = stage1_fraction_1 + stage1_fraction_2 + stage1_fraction_3 + stage1_fraction_4;
assign final_exp = (stage1_fraction[21]) ? stage1_exp_raw + 6'd1 : stage1_exp_raw;
assign final_mantissa = (stage1_fraction[21]) ? stage1_fraction[20:11] : stage1_fraction[19:10];

// Second-level pipeline processing
always @(posedge clk) begin
    if (stage1_zero_flag) begin
        product <= 16'b0;
    end else begin
        product <= (final_exp > 6'd30 ) ? 16'b0 : {stage1_sign, final_exp[4:0], final_mantissa};
    end
end

endmodule
