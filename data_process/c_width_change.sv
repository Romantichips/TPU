`timescale 1ns/1ps

`include "top.svh"

module c_width_change(
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic [`TPU_WIDTH*`MAX_DATA_BIT-1:0]     in_data,
    input  logic                                    in_data_valid,
    //need in_data_ready as backpresure signal，确保一次数据完整地分两次传完，输入再更换，防止被cover掉
    output logic                                    in_data_ready,

    output logic [`TPU_HEIGHT*`MAX_DATA_BIT-1:0]    out_data,
    output logic                                    out_data_valid
    //no need out_data_ready，下游为TPU数据高速处理，不需要复杂的控制，没必要设置ready，一直接收拆分的256bit即可
);

logic count;

//1）in_data_valid=1，mater给slave valid，slave 才能准备好给mater ready信号
//2）count=0， represent 第一次传，背压，in_data_ready=0，不得换下一批数据；count=1， represent 第二次传，第一批数据已经处理完毕，形成握手，mater可换下一批data inpout了
assign in_data_ready = &{in_data_valid, count};

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_data_valid <= 1'b0;
        count <= 1'b0;
    end else begin
        if(in_data_valid) begin
            count <= ~count;
        end
        out_data_valid <= in_data_valid;
    end
end

always_ff @(posedge clk) begin
    out_data <= (count) ? in_data[`TPU_WIDTH*`MAX_DATA_BIT-1:`TPU_HEIGHT*`MAX_DATA_BIT] : in_data[`TPU_HEIGHT*`MAX_DATA_BIT-1:0];
end

// -------------------------------------------

endmodule

