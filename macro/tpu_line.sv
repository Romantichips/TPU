`timescale 1ns/1ps

`include "top.svh"

module tpu_line #(
    parameter                        HEIGHT_ORDER = 0
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    //logic [1:0] n_size, 2'd0 is 8, 2'd1 is 16, 2'd2 is 32
    //logic [2:0] precision, 3'd0 is int4, 3'd1 is int8, 3'd2 is fp16, 3'd3 is fp32, 3'd4 is int32
    input  logic [1:0]               n_size,
    input  logic [2:0]               AB_precision,

    //data是从A矩阵中一次取16*32一行数据灌入，一个32bit数据对应一个valid，∵一行16*32的data不像一列16*32的weight一样同时写入PE中，∴1 valid 1 column weight。每个data，他的data+valid需要delay，∴ 1 data 1 delay
    input  logic [`TPU_WIDTH-1:0][`MAX_DATA_BIT-1:0] in_data,
    input  logic [`TPU_WIDTH-1:0]                    in_data_valid,

    input  logic [`TPU_WIDTH-1:0][`MAX_DATA_BIT-1:0] in_weight,
    input  logic [4:0]                               in_weight_addr,
    input  logic                                     in_weight_valid,

    output logic [`TPU_WIDTH-1:0][`MAX_DATA_BIT-1:0] out_data,
    output logic [`TPU_WIDTH-1:0]                    out_data_valid,

    output logic [`TPU_WIDTH-1:0][`MAX_DATA_BIT-1:0] out_weight,
    //[4:3] represent block number (8 column 1 block), and N max = 32 , so number max =3 ; [2:0] represent detailed column order in 1 block(8 column 1 block), max = 7
    output logic [4:0]                               out_weight_addr,
    //与data不同，一个out_weight_valid代表B矩阵中，一列16*32数据有效
    output logic                                     out_weight_valid,

    //1 valid 1 8*32(1 column) bias , ∵ 每行的bias 模块里有fifo控制读入读出 ∴完全可以1 valid 1 column bias, 节约资源
    input  logic [`MAX_DATA_BIT-1:0] in_c,
    input  logic                     in_c_valid,

    //需要这个信号控制bias的读出时机，不是像data&weight不停地流水线计算，一行的data和weight做乘积只需要一个c，∴若不控制，c一直灌这行，结果错误
    input  logic                     bias_read_in,
    output logic                     bias_read_out,

    output logic [`MAX_DATA_BIT-1:0] tpu_line_out_data
);

genvar i;

// -------------------------------------------

always @(posedge clk) begin
    out_weight_addr  <= in_weight_addr ;
    out_weight_valid <= in_weight_valid;
end

//暂存一行中0-15，共16个cell的输入/输出（in & out）
logic [`TPU_WIDTH:0] [`MAX_DATA_BIT-1:0] tmp_c;
//TPU_WIDTH=16，tmp_c[16]正好给到外围输出
assign tpu_line_out_data = tmp_c[`TPU_WIDTH];

generate
    for(i=0;i<`TPU_WIDTH;i=i+1) begin
        tpu_cell #(
            .HEIGHT_ORDER                    (HEIGHT_ORDER)
        ) tpu_cell (
            .clk                             (clk  ),
            .rst_n                           (rst_n),
            
            .n_size                          (n_size),
            .AB_precision                    (AB_precision),

            .in_data                         (in_data      [i]),
            .in_data_valid                   (in_data_valid[i]),

            .in_weight                       (in_weight[i]   ),
            .in_weight_addr                  (in_weight_addr ),
            .in_weight_valid                 (in_weight_valid),

            .out_data                        (out_data      [i]),
            .out_data_valid                  (out_data_valid[i]),

            .out_weight                      (out_weight[i]  ),
            //1）选择空接，而不是在该模块内例化。 ∵ 每个cell的pipeline计算存在时延，但weight的addr/valid传递是作为一个整体的
            //2）同样也符合data pipeline，weight fixed的原则
            .out_weight_addr                 (               ),
            .out_weight_valid                (               ),

            .c_in                            (tmp_c[i]),
            .c_out                           (tmp_c[i+1])
            //显然i max =15 ，整合tmp_c[16]就是该行的最终输出
        );
    end
endgenerate

tpu_bias tpu_bias (
    .clk                             (clk  ),
    .rst_n                           (rst_n),
    
    .c_data                          (in_c),
    .c_data_valid                    (in_c_valid),

    .bias_read_in                    (bias_read_in),
    .bias_read_out                   (bias_read_out),
    //第0个PE的输入,相当于bias决定第0个PE的输入，每行的bias模块独立于16个PE之外
    //bias ret
    .bias_read_data                  (tmp_c[0])
);

// -------------------------------------------

endmodule