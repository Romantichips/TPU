`timescale 1ns / 1ps

module FP16adder (
    input               clk,
    input       [15:0]  floatA,
    input       [15:0]  floatB,
    output reg  [15:0]  sum
);

// Stage 1: Alignment and Special Cases
reg         s1_special;
reg [5:0]   s1_exponent;
reg [10:0]  s1_fracA;
reg [10:0]  s1_fracB;
reg         s1_signA;
reg         s1_signB;
reg         s1_floatA_is0;
reg         s1_floatB_is0;
reg         signA_equal_signB;
always @(posedge clk) begin
    // Special circumstances marking
    if (floatA == 0 || floatB == 0 || (floatA[14:0] == floatB[14:0] && floatA[15]^floatB[15])) begin
        s1_special <= 1;
    end else begin
        s1_special <= 0;
    end
    // All situation handling (alignment)
    if (floatB[14:10] > floatA[14:10])begin
        s1_exponent <= floatB[14:10];
    end else begin
        s1_exponent <= floatA[14:10];
    end
    s1_fracA <= (floatB[14:10] > floatA[14:10]) ? {1'b1, floatA[9:0]} >> (floatB[14:10] - floatA[14:10]) : {1'b1, floatA[9:0]};
    s1_fracB <= (floatB[14:10] < floatA[14:10]) ? {1'b1, floatB[9:0]} >> (floatA[14:10] - floatB[14:10]) : {1'b1, floatB[9:0]};
    s1_signA <= floatA[15];
    s1_signB <= floatB[15];
    s1_floatA_is0 <= (floatA == 0);
    s1_floatB_is0 <= (floatB == 0);
    signA_equal_signB <= (floatA[15] == floatB[15]);
end

// Stage 2: Addition/Subtraction
reg         s2_special;
reg [5:0]   s2_exponent;
reg [10:0]  s2_frac;
reg         s2_sign;
wire [11:0] normal_frac; // Extra bit for carry
wire        normal_sign;

assign normal_frac = (signA_equal_signB) ? (s1_fracA + s1_fracB) :
                        (s1_fracA > s1_fracB) ? (s1_fracA - s1_fracB) : (s1_fracB - s1_fracA);
assign normal_sign = (signA_equal_signB) ? s1_signA :
                        (s1_fracA > s1_fracB) ? s1_signA : s1_signB;

always @(posedge clk) begin
    s2_special <= s1_special;
    if (s1_special) begin
        // Bypass computation for special cases
        s2_sign <= (s1_floatA_is0) ? s1_signB : s1_signA;
        s2_exponent <= s1_exponent;
        if (s1_floatA_is0) begin
            s2_frac <= s1_fracB;
        end else if (s1_floatB_is0) begin
            s2_frac <= s1_fracA;
        end else begin
            s2_frac <= 0;
        end
    end else begin
        // Actual computation
        s2_sign <= normal_sign;
        if (signA_equal_signB) begin        
            // Handle carry
            if (normal_frac[11]) begin 
                s2_exponent <= s1_exponent + 1;
                s2_frac <= normal_frac >> 1;
            end else begin
                s2_exponent <= s1_exponent;
                s2_frac <= normal_frac[10:0];
            end
        end else begin
            s2_exponent <= s1_exponent;
            s2_frac <= normal_frac[10:0];
        end
    end
end

// Stage 3: Normalization
genvar i;
wire [10:0] s2_frac_revert;
wire [10:0] s2_frac_hotcode;
wire [3:0]  s2_frac_location;
generate
    for(i=0;i<11;i=i+1) begin
        assign s2_frac_revert[i] = s2_frac[10-i];
    end
endgenerate
assign s2_frac_hotcode = s2_frac_revert & (~(s2_frac_revert-1));
assign s2_frac_location[0] = |{s2_frac_hotcode[1], s2_frac_hotcode[3], s2_frac_hotcode[5], s2_frac_hotcode[7], s2_frac_hotcode[9]};
assign s2_frac_location[1] = |{s2_frac_hotcode[2], s2_frac_hotcode[3], s2_frac_hotcode[6], s2_frac_hotcode[7], s2_frac_hotcode[10]};
assign s2_frac_location[2] = |{s2_frac_hotcode[4], s2_frac_hotcode[5], s2_frac_hotcode[6], s2_frac_hotcode[7]};
assign s2_frac_location[3] = |{s2_frac_hotcode[8], s2_frac_hotcode[9], s2_frac_hotcode[10]}; 

wire [10:0] normalized_frac;
wire [5:0]  normalized_exp;
assign normalized_frac = s2_frac << s2_frac_location;
assign normalized_exp = s2_exponent - s2_frac_location;

always @(posedge clk) begin
    if (s2_special) begin
        // Direct output for special cases
        if (s2_frac == 0)
            sum <= 0;
        else
            sum <= {s2_sign, s2_exponent[4:0], s2_frac[9:0]};
    end else begin
        // Normalized output
        if (normalized_exp > 6'd30 ) // Check underflow/overflow
            sum <= 0;
        else
            sum <= {s2_sign, normalized_exp[4:0], normalized_frac[9:0]};
    end
end

endmodule