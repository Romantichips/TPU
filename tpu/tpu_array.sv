`timescale 1ns/1ps

`include "top.svh"

module tpu_array (
    input  logic                     clk,
    input  logic                     rst_n,

    //logic [1:0] n_size, 2'd0 is 8, 2'd1 is 16, 2'd2 is 32
    //logic [2:0] precision, 3'd0 is int4, 3'd1 is int8, 3'd2 is fp16, 3'd3 is fp32, 3'd4 is int32
    input  logic [1:0]               n_size,
    input  logic [2:0]               AB_precision,
    
    input  logic [`TPU_WIDTH*`MAX_DATA_BIT-1:0] in_data,
    input  logic [`TPU_WIDTH-1:0]               in_data_valid,

    input  logic [`TPU_WIDTH*`MAX_DATA_BIT-1:0] in_weight,
    input  logic [4:0]                          in_weight_addr,
    input  logic                                in_weight_valid,

    // 1 valid signal represents 1 column bias data valid 
    input  logic [`TPU_HEIGHT-1:0][`MAX_DATA_BIT-1:0] in_c,
    input  logic                                      in_c_valid,

    output logic [`TPU_HEIGHT-1:0][`MAX_DATA_BIT-1:0] tpu_out_data
);

// -------------------------------------------

//regs for pipeplining 每一行的数据，权重级联
logic [`TPU_HEIGHT:0] [`TPU_WIDTH*`MAX_DATA_BIT-1:0] tmp_data;
logic [`TPU_HEIGHT:0] [`TPU_WIDTH-1:0]               tmp_data_valid;
assign tmp_data[0] = in_data;
assign tmp_data_valid[0] = in_data_valid;

logic [`TPU_HEIGHT:0] [`TPU_WIDTH*`MAX_DATA_BIT-1:0] tmp_weight;
logic [`TPU_HEIGHT:0] [4:0]                          tmp_weight_addr;
logic [`TPU_HEIGHT:0]                                tmp_weight_valid;
assign tmp_weight      [0] = in_weight      ;
assign tmp_weight_addr [0] = in_weight_addr ;
assign tmp_weight_valid[0] = in_weight_valid;

logic [`TPU_HEIGHT:0] tmp_bias_read;
//A*B+C，等待data*weight再+C，如果是MUL_DELAY则慢一拍，计算完了；只有MUL_DELAY-1，正好算完给下一级。
//why not every line a delay? cause delta of every line is const, not multiply dealy, so prepare initial bias, other bias pipeline delay is enough
delay # (
    .DELAY_NUM                  (`MUL_DELAY-1)
) delay (
    .clk                        (clk),
    //锚定第一个data进入的时候，考虑bias的加入
    .data_in                    (in_data_valid[0]),
    .data_out                   (tmp_bias_read[0])
);

//-------------------------------------------

genvar i;

generate
    for(i=0;i<`TPU_HEIGHT;i=i+1) begin
        // All in&out, means 级联
        tpu_line #(
            .HEIGHT_ORDER                    (i)
        ) tpu_line (
            .clk                             (clk  ),
            .rst_n                           (rst_n),
            
            .n_size                          (n_size),
            .AB_precision                    (AB_precision),

            .in_data                         (tmp_data      [i]),
            .in_data_valid                   (tmp_data_valid[i]),

            .out_data                        (tmp_data      [i+1]),
            .out_data_valid                  (tmp_data_valid[i+1]),

            .in_weight                       (tmp_weight      [i]),
            .in_weight_addr                  (tmp_weight_addr [i]),
            .in_weight_valid                 (tmp_weight_valid[i]),

            .out_weight                      (tmp_weight      [i+1]),
            .out_weight_addr                 (tmp_weight_addr [i+1]),
            .out_weight_valid                (tmp_weight_valid[i+1]),

            .in_c                            (in_c[i]),
            .in_c_valid                      (in_c_valid),

            .bias_read_in                    (tmp_bias_read[i]),
            .bias_read_out                   (tmp_bias_read[i+1]),

            .tpu_line_out_data               (tpu_out_data[i])
        );
    end
endgenerate

// -------------------------------------------

endmodule