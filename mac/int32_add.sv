`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 21:08:39
// Design Name: 
// Module Name: int8_add
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


module int32_add (
    input clk,
    input signed [31:0] a,      // 8-bit signed number
    input signed [31:0] b,      // 8-bit signed number
    output reg  signed [31:0] sum    // 8-bit signed number sum
);
    wire signed [32:0] sum_full;
    assign sum_full = a + b;
    always@(posedge clk)begin
        case(sum_full[32:31])
            2'b01: sum <= 32'h7FFFFFFF; // Consider the case of the positive boundary
            2'b10: sum <= 32'h80000000; // Consider the case of the negative boundary
            default: sum <= sum_full; 
        endcase
    end
endmodule 