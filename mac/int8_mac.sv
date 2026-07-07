`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/01 10:40:23
// Design Name: 
// Module Name: int8_mac
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


module int8_mac(
    input  logic        clk,
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [31:0] c,
    output logic [31:0] result
);
    wire signed [31:0] product_wire;
    // 8-bit signed number multiplication
    int8_mult uut(
        .clk(clk),
        .a(a),
        .b(b),
        .product(product_wire)
    );
    // 32-bit signed number addition
    int32_add oot(
        .clk(clk),
        .a(product_wire),
        .b(c),
        .sum(result)
    );     
endmodule