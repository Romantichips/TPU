`timescale 1ns/1ps
`include "top.svh"

module label_address#(
    parameter integer             DATA_WIDTH = 512
)(
    //func:本质就是数据向地址的转换，分配了一下B矩阵每列数据的地址
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic [DATA_WIDTH-1:0] data,
    input  logic                  is_first_data,
    input  logic                  data_valid,
    output logic                  data_ready,
    
    output logic [DATA_WIDTH-1:0] weight,
    // B matrix max 32 columns, so 5bits are enough to address each line
    output logic [4:0]            weight_addr,
    output logic                  weight_valid
);

// this module is not like c_width_change need 2 pipe to cope data, this module 1 pipe ok, so always data_ready=1 to cope new data
//assign data_ready = data_valid;
assign data_ready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        weight_valid <= 1'b0;
    end else begin
        weight_valid <= data_valid;
    end
end

always_ff @(posedge clk) begin
    weight <= data;
    if(data_valid) begin
        if(is_first_data) begin
            weight_addr <= 5'd0;
        end else begin
            weight_addr <= weight_addr + 1'b1;
        end
    end
end

endmodule