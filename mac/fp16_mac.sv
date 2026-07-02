`timescale 1ns / 1ps

module fp16_mac (
    input  logic        clk,
    input  logic [15:0] a,
    input  logic [15:0] b,
    input  logic [15:0] c,
    output logic [31:0] result
);

// Input register (2-level buffer aligned multiplier delay)
reg  [15:0] floatC_reg[1:0];
wire [15:0] product;
wire [15:0] add_result;
//Delay for c
always @(posedge clk) begin
        floatC_reg[0] <= c[15:0];
        floatC_reg[1] <= floatC_reg[0];
end
// Multiplier instance (2-stage pipeline)
FP16multiply mult (
    .clk(clk),
    .floatA(a),
    .floatB(b),
    .product(product)
);
// Adder instance (3-stage pipeline)
FP16adder adder (
    .clk(clk),
    .floatA(product),
    .floatB(floatC_reg[1]),
    .sum(add_result)
);
always @(posedge clk) begin
    // Output result register
    result <= {16'b0, add_result};
end
endmodule