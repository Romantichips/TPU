`timescale 1ns/1ps

`include "top.svh"
    //Func:based on D precision info, perform bit cut, and merge 512bit data
module bit_cut   #(
    parameter integer                             DATA_WIDTH = 512
) (
    input  logic                                  clk,
    input  logic                                  rst_n,

    //logic [2:0] precision, 3'd0 is int4, 3'd1 is int8, 3'd2 is fp16, 3'd3 is fp32, 3'd4 is int32
    input  logic  [2:0]                           D_precision,
    //256 bit in
    input  logic  [`TPU_HEIGHT*`MAX_DATA_BIT-1:0] in_data,
    //对齐后的8*32位数据，1 valid 1 column
    input  logic                                  in_data_valid,
    //512 bit out
    output logic  [`TPU_WIDTH*`MAX_DATA_BIT-1:0]  out_data,
    //同理
    output logic                                  out_data_valid
);

logic [`TPU_HEIGHT*4-1:0]  cut_data_int4; 
logic [`TPU_HEIGHT*8-1:0]  cut_data_int8;  
logic [`TPU_HEIGHT*16-1:0] cut_data_fp16; 
logic [`TPU_HEIGHT*32-1:0] cut_data_fp32; 

always_comb begin
    for (int i = 0; i < `TPU_HEIGHT; i++) begin
        cut_data_int4[i*4  +: 4]  = in_data [i*`MAX_DATA_BIT +: 4];    // int4
        cut_data_int8[i*8  +: 8]  = in_data [i*`MAX_DATA_BIT +: 8];    // int8
        cut_data_fp16[i*16 +: 16] = in_data [i*`MAX_DATA_BIT +: 16];   // fp16
        cut_data_fp32             = in_data ;                          // fp32/int32
    end
end

logic enable_1, enable_2, enable_3; 

always_comb begin
    case (D_precision)
        3'b000: begin       // INT4
            enable_1 = 1'b1;
            enable_2 = 1'b1;
            enable_3 = 1'b1;
        end
        3'b001: begin       // INT8
            enable_1 = 1'b0;
            enable_2 = 1'b1;
            enable_3 = 1'b1;
        end
        3'b010: begin       // FP16
            enable_1 = 1'b0;
            enable_2 = 1'b0;
            enable_3 = 1'b1;
        end
        default: begin     // FP32 or INT32
            enable_1 = 1'b0;
            enable_2 = 1'b0;
            enable_3 = 1'b0;
        end
    endcase
end

logic merge1_valid;
logic merge2_valid;
logic merge3_valid;
logic [`TPU_HEIGHT*8-1:0] merge1_data;
logic [`TPU_HEIGHT*16-1:0] merge2_data;
logic [`TPU_HEIGHT*32-1:0] merge3_data;

//不根据D精度去配数据，而是依据不同精度并行拆分，对于16bit 配 32bit的，你无法确认到底输入的直接就是16bit 或者 是由 4bit or 8bit 拼凑上去的

data_merge #(
    .DATA_WIDTH(`TPU_HEIGHT * 4)
) data_merge_stage1 (
    .clk        (clk),
    .rst        (~rst_n)                ,
    .in_data    (cut_data_int4)         ,   
    .in_valid   (in_data_valid)         , 
    .out_data   (merge1_data)           ,   
    .out_valid  (merge1_valid)          
);

 data_merge #(
    .DATA_WIDTH(`TPU_HEIGHT * 8)
) data_merge_stage2 (
    .clk        (clk),
    .rst        (~rst_n)                                    ,
    .in_data    (enable_1 ? merge1_data: cut_data_int8)     ,   
    .in_valid   (enable_1 ? merge1_valid : in_data_valid)   , 
    .out_data   (merge2_data)                               ,   
    .out_valid  (merge2_valid)          
);

data_merge #(
    .DATA_WIDTH(`TPU_HEIGHT*16)
) data_merge_stage3 (
    .clk        (clk),
    .rst        (~rst_n)                                         ,
    .in_data    (enable_2 ? merge2_data  : cut_data_fp16)        ,   
    .in_valid   (enable_2 ? merge2_valid : in_data_valid)        , 
    .out_data   (merge3_data)                                    ,   
    .out_valid  (merge3_valid)         
);

data_merge #(
    .DATA_WIDTH(`TPU_HEIGHT*32)
) data_merge_stage4 (
    .clk        (clk),
    .rst        (~rst_n)                                     ,
    .in_data    (enable_3 ? merge3_data  : cut_data_fp32)    ,   
    .in_valid   (enable_3 ? merge3_valid : in_data_valid)    , 
    .out_data   (out_data)                                   ,   
    .out_valid  (out_data_valid)                    
);

//logic empty;
//assign out_data_valid = ~ empty;
//
//xxm_scfifo_mixed_width #(
//    .WR_DATA_WIDTH                         (`TPU_HEIGHT*`MAX_DATA_BIT),
//    .RD_DATA_WIDTH                         (`TPU_WIDTH*`MAX_DATA_BIT)
//) xxm_scfifo_mixed_width (
//    .clk                                   (clk),
//    .rst                                   (~rst_n),
//
//    .in_data                               (in_data),
//    .wrreq                                 (in_data_valid),
//    .usedw                                 (),
//    .full                                  (),
//    .prog_full                             (),
//
//    .rdreq                                 (out_data_valid),
//    .out_data                              (out_data),
//    .empty                                 (empty)
//);

// -------------------------------------------
 
endmodule