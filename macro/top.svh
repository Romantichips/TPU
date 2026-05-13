`ifndef TOP_SVH
`define TOP_SVH

// ------------------------------------------- MACRO

`define TPU_HEIGHT 8
`define TPU_WIDTH  16

`define MAX_DATA_BIT 32

//this is the delay of int 8 precision
`define MUL_DELAY 2
`define ADD_DELAY 1

// int4
//`define MUL_DELAY 1
//`define ADD_DELAY 1

//fp16
//`define MUL_DELAY 2
//`define ADD_DELAY 3

//fp32
//`define MUL_DELAY 5
//`define ADD_DELAY 4

`define A_START_ADDRESS 32'h0000_0000
`define B_START_ADDRESS 32'h0001_0000
`define C_START_ADDRESS 32'h0002_0000
`define D_START_ADDRESS 32'h0003_0000

// ------------------------------------------- test

`define M_DIM 32
`define N_DIM 8

// this verification used 8, 32 ,it can be modified if you want to test other precision and other martrix
`define AB_PRECISION 8
`define C_PRECISION  8
`define D_PRECISION  32

// -------------------------------------------

`endif
