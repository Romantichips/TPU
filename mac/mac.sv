`timescale 1ns / 1ps

module mac (
    input  logic        clk,
    
    //3'd0 is int4, 3'd1 is int8, 3'd2 is fp16, 3'd3 is fp32, 3'd4 is int32
    input  logic [2:0]  AB_precision,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [31:0] c,
    output logic [31:0] result
);

    logic [31:0] result_int8;
    logic [31:0] result_fp16;
    logic [31:0] result_fp32;

    //int4 and int8 integrated
    int8_mac mac_int8 (
        .clk(clk),
        .a(a[7:0]),        
        .b(b[7:0]),        
        .c(c),             
        .result(result_int8)  
    );

    fp16_mac mac_fp16 (
        .clk(clk),
        .a(a[15:0]),       
        .b(b[15:0]),       
        .c(c[15:0]),             
        .result(result_fp16)  
    );

    fp32_mac mac_fp32 (
        .clk(clk),
        .a(a),             
        .b(b),             
        .c(c),             
        .result(result_fp32)  
    );

    always_comb begin
        case (AB_precision)
            3'b010: result = result_fp16;  
            3'b011: result = result_fp32;  
            default: result = result_int8;       
        endcase
    end
endmodule