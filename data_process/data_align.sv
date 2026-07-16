`timescale 1ns/1ps

`include "top.svh"

module data_align (
    input  logic                     clk,
    input  logic                     rst_n,

    //data process only, no control logic 
    input  logic  [`TPU_HEIGHT-1:0][`MAX_DATA_BIT-1:0] tpu_in_data,
    output logic  [`TPU_HEIGHT-1:0][`MAX_DATA_BIT-1:0] tpu_out_data
);

genvar i;

// -------------------------------------------

//first out wait 7 pipes，secned out wait 6 pipes and so on ∵ 第一个数据结束之后，过7拍剩余7行数据全部出来，可以对齐
generate
    for(i=0;i<`TPU_HEIGHT;i=i+1) begin  
        delay #(
            .WIDTH_NUM(`MAX_DATA_BIT  ),
            .DELAY_NUM(`TPU_HEIGHT-1-i)
        ) delay_inst (
            .clk(clk),
            .data_in (tpu_in_data[i] ),
            .data_out(tpu_out_data[i])
        );
    end
endgenerate

endmodule