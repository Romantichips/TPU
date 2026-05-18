`timescale 1ns/1ps

`include "top.svh"

module tpu_bias (
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic [`MAX_DATA_BIT-1:0] c_data,
    //write in 
    input  logic                     c_data_valid,
    //read out
    input  logic                     bias_read_in,
    //read out(bias_read_in) passed signal
    output logic                     bias_read_out,

    //bias ret
    output logic [`MAX_DATA_BIT-1:0] bias_read_data
);

// -------------------------------------------

logic [`MAX_DATA_BIT-1:0] out_data;

xxm_scfifo #(
    .DATA_WIDTH                            (`MAX_DATA_BIT)
) xxm_scfifo (
    .clk                                   (clk),
    .rst                                   (~rst_n),
    //write in & data
    .in_data                               (c_data),
    .wrreq                                 (c_data_valid),
    .usedw                                 (),
    .full                                  (),
    .prog_full                             (),
    //read out & data
    .rdreq                                 (bias_read_in),
    .out_data                              (out_data),
    .empty                                 ()
);

// no reg, fifo did it 
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bias_read_out <= 1'b0;
    end else begin
        bias_read_out <= bias_read_in;
    end
end

always_ff @(posedge clk) begin
    bias_read_data <= out_data;
end

// -------------------------------------------

endmodule