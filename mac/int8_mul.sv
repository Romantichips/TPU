`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 21:09:30
// Design Name: 
// Module Name: int8_mult
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

module int8_mult (
    input clk,
    input signed [7:0] a,       // 8-bit signed number
    input signed [7:0] b,       // 8-bit signed number
    output reg signed [31:0] product // 8-bit signed number product
);

    always@(posedge clk)begin
        product<=a*b;
    end
endmodule  