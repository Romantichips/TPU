`timescale 1ns / 1ps

module FP32adder(
    input wire clk,
    input wire [31:0] floatA,
    input wire [31:0] floatB,
    output reg [31:0] sum
);

    // Stage 1 of the assembly line: Alignment processing
    reg         special_s2;
    reg [31:0]  special_floatA_s2;
    reg [31:0]  special_floatB_s2;
    reg         signA_stage2;
    reg         signB_stage2;
    reg [23:0]  fractionA_stage2;
    reg [23:0]  fractionB_stage2; 
    reg [7:0]   exponent_stage2;
    //  With hidden bits
    always @(posedge clk) begin
        if(floatA == 0 || floatB == 0 || ((floatA[31] ^  floatB[31] ==1) && (floatA[30:0] == floatB[30:0])))begin
           special_s2 <= 1;      
        end else begin
            special_s2 <= 0; 
        end
        special_floatA_s2<=floatA;
        special_floatB_s2<=floatB; 
        signA_stage2 <= floatA[31];
        signB_stage2 <= floatB[31];        
        // Alignment processing
        if (floatB[30:23] > floatA[30:23]) begin
            fractionA_stage2 <= {1'b1,floatA[22:0]} >> (floatB[30:23] - floatA[30:23]);
            fractionB_stage2 <= {1'b1,floatB[22:0]};
            exponent_stage2 <= floatB[30:23];
        end else begin
            fractionB_stage2 <= {1'b1,floatB[22:0]} >> (floatA[30:23] - floatB[30:23]);
            fractionA_stage2 <= {1'b1,floatA[22:0]};
            exponent_stage2 <= floatA[30:23];
        end
    end

    // Stage 2 of the assembly line: Addition and subtraction operations
    reg         special_s3;
    reg [31:0]  special_floatA_s3;
    reg [31:0]  special_floatB_s3;
    reg [7:0]   exponent_result_stage3;    
    reg [24:0]  fraction_result_stage3; // 25 results (including the carry bit)
    reg         sign_result_stage3;         
    always @(posedge clk) begin
        special_s3<=special_s2;
        special_floatA_s3<=special_floatA_s2;
        special_floatB_s3<=special_floatB_s2;
        exponent_result_stage3 <= exponent_stage2;        
        // Perform addition or subtraction
        if (signA_stage2 == signB_stage2) begin
            // Add numbers with the same digit
            fraction_result_stage3[24:0] <=  fractionA_stage2 + fractionB_stage2;
            sign_result_stage3 <= signA_stage2;
        end else begin
            // Subtraction of unlike terms
            if (fractionA_stage2 >= fractionB_stage2) begin
                fraction_result_stage3 <= fractionA_stage2 - fractionB_stage2;
                sign_result_stage3 <= signA_stage2;
            end else begin
                fraction_result_stage3 <= fractionB_stage2 - fractionA_stage2;
                sign_result_stage3 <= signB_stage2;
            end
        end
    end

    // Stage 3 of the assembly line: Normalization processing
    reg         special_s4;
    reg [31:0]  special_floatA_s4;
    reg [31:0]  special_floatB_s4;
    reg         sign_stage4;        
    reg [22:0]  fraction_stage4;
    reg [7:0]   exponent_stage4;
    integer i;  
    always @(posedge clk) begin
        special_s4<=special_s3;
        special_floatA_s4<=special_floatA_s3;
        special_floatB_s4<=special_floatB_s3;   
        sign_stage4 <= sign_result_stage3;        
        if (fraction_result_stage3[24]) begin
            // Result overflow - Shift right and increase the exponent
            fraction_stage4 <= fraction_result_stage3[23:1];
            exponent_stage4 <= exponent_result_stage3 + 1;
        end else if (fraction_result_stage3[23] == 1'b0) begin
            // Need to perform left normalization
            for (i = 22; i >= 0; i = i - 1) begin : norm_loop
                if (fraction_result_stage3[i]) begin
                    fraction_stage4 <= fraction_result_stage3[22:0] << (23 - i);
                    exponent_stage4 <= exponent_result_stage3 - (23 - i);
                    disable norm_loop;
                end
            end
        end else begin
            // It has been standardized.
            fraction_stage4 <= fraction_result_stage3[22:0];
            exponent_stage4 <= exponent_result_stage3;
        end
    end

    // Stage 4 of the assembly line: Result output
    always @(posedge clk) begin
        if(special_s4)begin
            if(special_floatA_s4 == 0 )begin
                sum<=special_floatB_s4 ;
            end else if( special_floatB_s4 == 0 )begin
                sum<=special_floatA_s4 == 0 ;
            end else 
                sum<=0;
        end else 
            sum <= {sign_stage4, exponent_stage4, fraction_stage4};
    end
endmodule