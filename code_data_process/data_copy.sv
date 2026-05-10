`timescale 1ns/1ps

`include "top.svh"

module data_copy #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic [1:0]               n_size,

    input  logic [DATA_WIDTH-1:0]    in_data      ,
    input  logic                     in_data_valid,
    output logic                     in_data_ready,

    output logic [DATA_WIDTH-1:0]    out_data      ,
    output logic                     out_data_valid
);

// when n is 0, no copy
// when n is 1, copy 1
// when n is 2, copy 3

logic prog_full;
logic [1:0] data_cnt;
logic [1:0] data_num;

always_ff@(posedge clk) begin
    case (n_size)
        2'b00:   begin data_num <= 2'b00; end
        2'b01:   begin data_num <= 2'b01; end
        2'b10:   begin data_num <= 2'b11; end
        default: begin data_num <= 2'b00; end
    endcase
end

//func: cnt
always_ff@(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        data_cnt <= 2'b00;
    end else begin
        if(&{in_data_valid, ~prog_full}) begin
            if(data_cnt == data_num) begin
                data_cnt <= 2'b00;
            end else begin
                data_cnt <= data_cnt + 1'b1;
            end
        end
    end
end

assign in_data_ready = &{in_data_valid, ~prog_full, data_cnt == data_num};
//only 输入信号有效+未满+复制次数上限，告知上游模块可以继续输入数据

wire empty;

xxm_scfifo #(
    .DATA_WIDTH                            (DATA_WIDTH)
) xxm_scfifo (
    .clk                                   (clk),
    .rst                                   (~rst_n),

    .in_data                               (in_data),
    .wrreq                                 (&{in_data_valid, ~prog_full}),
    .usedw                                 (),
    .full                                  (),
    .prog_full                             (prog_full),

    .rdreq                                 (~empty),
    .out_data                              (out_data),
    .empty                                 (empty)
);

assign out_data_valid = ~empty;

// -------------------------------------------

endmodule