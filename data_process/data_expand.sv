`timescale 1ns/1ps

`include "top.svh"

module data_expand #(
    parameter integer                DATA_WIDTH = 512,
    parameter integer                VALID_BIT_WIDTH = 4
) (
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic [1:0]               in_precision    ,
    input  logic [1:0]               in_data_address ,
    input  logic                     in_is_first_data,
    input  logic [DATA_WIDTH-1:0]    in_data         ,
    input  logic                     in_valid        ,
    output logic                     in_ready        ,

    input  logic                     condition_extend,

    output logic [1:0]               out_precision    ,
    output logic [1:0]               out_data_address ,
    output logic                     out_is_first_data,
    output logic [DATA_WIDTH-1:0]    out_data         ,
    output logic                     out_valid        ,
    input  logic                     out_ready        
);

genvar i;

// -------------------------------------------

//配置pipe_1_1to2的ch0和ch1
logic [1:0] [1:0]            tmp_precision    ;
logic [1:0] [1:0]            tmp_data_address ;
logic [1:0]                  tmp_is_first_data;
logic [1:0] [DATA_WIDTH-1:0] tmp_data         ;
logic [1:0]                  tmp_valid        ;
logic [1:0]                  tmp_ready        ;

pipe_1_1to2 #(
    .DATA_WIDTH                   (2+2+1+DATA_WIDTH)
) pipe_1_1to2 (
    .clk                          (clk),
    .rst                          (~rst_n),

    .in_ready                     (in_ready),
    .in_valid                     (in_valid),
    //condition_extend=1，满足条件（应该是被数据扩展的data）从ch1出，不符合从ch0出，不经过功能模块，最后pipe_1_2to1的从ch0出
    .in_id                        (condition_extend),
    .in_data                      ({in_precision, in_data_address, in_is_first_data, in_data}),

    .out_0_ready                  (tmp_ready[0]),
    .out_0_valid                  (tmp_valid[0]),
    .out_0_data                   ({tmp_precision[0], tmp_data_address[0], tmp_is_first_data[0], tmp_data[0]}),

    .out_1_ready                  (tmp_ready[1]),
    .out_1_valid                  (tmp_valid[1]),
    .out_1_data                   ({tmp_precision[1], tmp_data_address[1], tmp_is_first_data[1], tmp_data[1]})
);
 
// -------------------------------------------

//1次in_data分2次发送
logic [DATA_WIDTH/(VALID_BIT_WIDTH*2)-1:0] [VALID_BIT_WIDTH*2-1:0] data_part_0;
logic [DATA_WIDTH/(VALID_BIT_WIDTH*2)-1:0] [VALID_BIT_WIDTH*2-1:0] data_part_1;

generate
    for(i=0;i<DATA_WIDTH/(VALID_BIT_WIDTH*2);i=i+1) begin
        //∵tmpdata里面每VALID_BIT_WIDTH位扩成：（VALID_BIT_WIDTH个符号位（原数据最高位）+VALID_BIT_WIDTH原数据）
        //data_part_0是tmp_data[255：0]；data_part_1是tmp_data[512：256]
        assign data_part_0[i] = {{(VALID_BIT_WIDTH){tmp_data[1][(i*VALID_BIT_WIDTH)+VALID_BIT_WIDTH-1]}}, tmp_data[1][(i*VALID_BIT_WIDTH)+:VALID_BIT_WIDTH]};
        assign data_part_1[i] = {{(VALID_BIT_WIDTH){tmp_data[1][(DATA_WIDTH/2+i*VALID_BIT_WIDTH)+VALID_BIT_WIDTH-1]}}, tmp_data[1][(DATA_WIDTH/2+i*VALID_BIT_WIDTH)+:VALID_BIT_WIDTH]};
    end
endgenerate

//----------------------------------------------

//tip：nxt系列，全部配给pipe_1_2to1的ch1的数据
logic [1:0]            nxt_precision    ;
logic [1:0]            nxt_data_address ;
logic                  nxt_is_first_data;
logic [DATA_WIDTH-1:0] nxt_data         ;
logic                  nxt_valid        ;
//一个内部模块的输出信号
logic                  nxt_ready        ;

logic cnt;
// 1）cnt=1（即0，1两次，表示发送2次） 2）pipe_1_2to1的nxt_ready=1，表示该模块的对应ch可以继续处理数据，处理完一次数据就置高表示可以处理下一次，0，1，正好第二次发送完置高
assign tmp_ready[1] = &{cnt, nxt_ready};

//显然nxt_precision不会因为一组tmp[1]拆2次发送而改变；nxt_valid同样，2次数据均valid=1有效；nxt_data_address一样；
assign nxt_valid         = tmp_valid[1];
assign nxt_precision     = tmp_precision[1];
assign nxt_data_address  = tmp_data_address[1];

//∵一组tmp[1]拆2次发送,又一组tmp[1]（in_data）只配一个nxt_is_first_data，∴nxt_is_first_data配给拆分后第一次发送的数据（用于区分拆分后的2股数据）
assign nxt_is_first_data = (cnt) ? 1'b0 : tmp_is_first_data[1];
//cnt 0/1 翻转发送数据
assign nxt_data          = (cnt) ? data_part_1 : data_part_0;

always_ff @(posedge clk or negedge rst_n) begin
    //cnt虽然是data。但是存在rst_n，∵cnt不能有不定态，cnt的取值会改变控制逻辑，与控制信号强相关
    if (!rst_n) begin
        cnt <= 1'b0;
    end else begin
        //tip:被拆分的2次数据，每发送完1次，握手，cnt翻转
        if(&{tmp_valid[1], nxt_ready}) begin
            cnt <= ~cnt;
            //cnt <= 1'b1;
        end
        //cnt <= (cnt) ? ~nxt_ready: &{tmp_valid[1], nxt_ready};
    end
end

// -------------------------------------------

pipe_1_2to1 #(
    .DATA_WIDTH                   (2+2+1+DATA_WIDTH)
    //配置精度、地址、首信号、数据，参看模块的输出信号
) pipe_1_2to1 (
    .clk                          (clk),
    .rst                          (~rst_n),

    .in_0_ready                   (tmp_ready[0]),
    .in_0_valid                   (tmp_valid[0]),
    .in_0_data                    ({tmp_precision[0], tmp_data_address[0], tmp_is_first_data[0], tmp_data[0]}),

    .in_1_ready                   (nxt_ready),
    .in_1_valid                   (nxt_valid),
    .in_1_data                    ({nxt_precision, nxt_data_address, nxt_is_first_data, nxt_data}),

    .out_ready                    (out_ready),
    .out_valid                    (out_valid),
    //不care到底是ch0 or ch1 读出的数据
    .out_id                       (),
    .out_data                     ({out_precision, out_data_address, out_is_first_data, out_data})
);

// -------------------------------------------

endmodule