`timescale 1ns / 1ps

module fp32_mac (
    input  logic        clk,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [31:0] c,
    output logic [31:0] result
);
// Floating-point multiplication and addition
reg [31:0] floatC_reg[4:0];
wire [31:0] product;

always @(posedge clk) begin
        floatC_reg[0] <= c;
        floatC_reg[1] <= floatC_reg[0];
        floatC_reg[2] <= floatC_reg[1];
        floatC_reg[3] <= floatC_reg[2];
        floatC_reg[4] <= floatC_reg[3];
end
// Floating-point multiplication
FP32multiply mult (
    .clk(clk),
    .floatA(a),
    .floatB(b),
    .product(product)
);
// Floating-point addition
FP32adder adder (
    .clk(clk),
    .floatA(product),
    .floatB(floatC_reg[4]), 
    .sum(result)
);

endmodule