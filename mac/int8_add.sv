`timescale 1ns / 1ps

module int8_add (
    input  logic        clk,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);

// result delay obey `ADD_DELAY in top.svh

endmodule