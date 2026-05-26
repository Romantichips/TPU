`timescale 1ns/1ps

`include "top.svh"

module data_split #(
    parameter integer                DATA_WIDTH = 512
) (
    input  logic                     clk,
    input  logic                     rst_n,
    
    input  logic                     data_valid   ,
    output logic                     data_ready   ,
    input  logic [1:0]               data_address ,
    //is_first_data_in：ABC每股512bit写入都会携带一个，标识每一股新的数据
    input  logic                     is_first_data_in,
    input  logic [DATA_WIDTH-1:0]    data         ,

    output logic [DATA_WIDTH-1:0]    A_data      ,
    output logic                     A_data_valid,
    input  logic                     A_data_ready,

    output logic [DATA_WIDTH-1:0]    B_data       ,
    //is_first_data_out：A,B,C数据流一齐写入，区分B数据的第一股512bit data
    output logic                     is_first_data_out,
    output logic                     B_data_valid ,
    input  logic                     B_data_ready ,

    output logic [DATA_WIDTH-1:0]    C_data      ,
    output logic                     C_data_valid,
    input  logic                     C_data_ready
);

// based on data address, data transfer to the corresponding interface（接口）
// data_address[1:0] = 00 -> A
// data_address[1:0] = 01 -> B 
// data_address[1:0] = 02(10) -> C
// is_first_data is used for weight address generator

logic ready_AB;
logic valid_AB;
logic [DATA_WIDTH-1:0] data_AB;

logic data_address_AB;
logic data_address_C;

logic is_first_data_AB;
logic is_first_data_C;
logic is_first_data_A;

//分开AB和C，显然不需要is_first_data_C标识了
pipe_1_1to2 #(
    .DATA_WIDTH                   (1+1+DATA_WIDTH)
) split_AB_and_C (
    .clk                          (clk),   
    .rst                          (~rst_n),   

    .in_ready                     (data_ready),
    .in_valid                     (data_valid),
    .in_id                        (data_address[1]), // 0 for ch 0, 1 for ch 1
    //addr[1] to distinguish AB and C addr diffrence, cause C addr[1] is 1, but AB addr[1] is 0 
    .in_data                      ({data_address[0], is_first_data_in, data}),

    .out_0_ready                  (ready_AB),
    .out_0_valid                  (valid_AB),
    //data_address_AB有0/1两种，便于第二级拆分A，B
    .out_0_data                   ({data_address_AB, is_first_data_AB, data_AB}),

    .out_1_ready                  (C_data_ready),
    .out_1_valid                  (C_data_valid),
    .out_1_data                   ({data_address_C, is_first_data_C, C_data})
);

pipe_1_1to2 #(
    .DATA_WIDTH                   (1+DATA_WIDTH)
) split_A_and_B (
    .clk                          (clk),   
    .rst                          (~rst_n),   

    .in_ready                     (ready_AB),
    .in_valid                     (valid_AB),
    .in_id                        (data_address_AB), // 0 for ch 0, 1 for ch 1
    .in_data                      ({is_first_data_AB, data_AB}),

    .out_0_ready                  (A_data_ready),
    .out_0_valid                  (A_data_valid),
    .out_0_data                   ({is_first_data_A, A_data}),

    .out_1_ready                  (B_data_ready),
    .out_1_valid                  (B_data_valid),
    //is_first_data_out=is_first_data_B，区分B
    //tip：单独设is_first_data_out，∵A,B是否是第一股数据不care，只作data process；而B martrix需要is_first_data_out重新分配地址写入脉动阵列的不同位置
    .out_1_data                   ({is_first_data_out, B_data})
);

// -------------------------------------------

endmodule